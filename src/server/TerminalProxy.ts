import type { FileSink } from 'bun'

interface TerminalCallbacks {
  onData: (data: string) => void
  onExit?: () => void
}

interface PtyProcess {
  stdin: FileSink
  stdout: ReadableStream<Uint8Array>
  stderr: ReadableStream<Uint8Array>
  exited: Promise<number>
  kill(): void
  resize?: (cols: number, rows: number) => void
}

export class TerminalProxy {
  private process: PtyProcess | null = null
  private decoder = new TextDecoder()
  private encoder = new TextEncoder()

  constructor(
    private tmuxWindow: string,
    private callbacks: TerminalCallbacks
  ) {}

  start(): void {
    if (this.process) {
      return
    }

    const proc = Bun.spawn([
      'tmux',
      'attach',
      '-t',
      this.tmuxWindow,
    ], {
      stdin: 'pipe',
      stdout: 'pipe',
      stderr: 'pipe',
      env: {
        ...process.env,
        TERM: 'xterm-256color',
        COLORTERM: 'truecolor',
        TMUX: undefined,
      },
    }) as unknown as PtyProcess

    this.process = proc

    this.readStream(proc.stdout)
    this.readStream(proc.stderr)

    proc.exited.then(() => {
      this.callbacks.onExit?.()
    })
  }

  write(data: string): void {
    if (!this.process) {
      return
    }

    this.process.stdin.write(this.encoder.encode(data))
  }

  resize(cols: number, rows: number): void {
    if (this.process?.resize) {
      this.process.resize(cols, rows)
      return
    }

    try {
      Bun.spawnSync([
        'tmux',
        'resize-window',
        '-t',
        this.tmuxWindow,
        '-x',
        String(cols),
        '-y',
        String(rows),
      ])
    } catch {
      // Ignore resize failures; terminal will still work.
    }
  }

  dispose(): void {
    if (!this.process) {
      return
    }

    try {
      this.process.kill()
    } catch {
      // Ignore if already exited.
    }

    this.process = null
  }

  private async readStream(stream: ReadableStream<Uint8Array> | null) {
    if (!stream) {
      return
    }

    const reader = stream.getReader()
    while (true) {
      const { value, done } = await reader.read()
      if (done) {
        break
      }
      if (value) {
        this.callbacks.onData(this.decoder.decode(value))
      }
    }
  }
}
