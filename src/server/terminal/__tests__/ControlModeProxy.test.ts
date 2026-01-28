// src/server/terminal/__tests__/ControlModeProxy.test.ts

import { describe, expect, it, mock } from 'bun:test'
import { ControlModeProxy } from '../ControlModeProxy'
import type { TerminalProxyOptions } from '../types'

describe('ControlModeProxy', () => {
  const createMockProcess = () => {
    const stdoutController = { current: null as ReadableStreamDefaultController<Uint8Array> | null }
    const stdout = new ReadableStream<Uint8Array>({
      start(controller) {
        stdoutController.current = controller
      }
    })
    return {
      stdin: {
        write: mock(() => 0)
      },
      stdout,
      stdoutController,
      kill: mock(() => {}),
      exited: new Promise<void>(() => {})
    }
  }

  const createOptions = (overrides: Partial<TerminalProxyOptions> = {}): TerminalProxyOptions => ({
    connectionId: 'test-conn',
    sessionName: 'test-session',
    baseSession: 'agentboard',
    onData: mock(() => {}),
    onEvent: mock(() => {}),
    spawn: mock(() => createMockProcess()) as any,
    spawnSync: mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') })) as any,
    ...overrides
  })

  describe('getMode()', () => {
    it('returns control-mode', () => {
      const proxy = new ControlModeProxy(createOptions())
      expect(proxy.getMode()).toBe('control-mode')
    })
  })

  describe('getClientTty()', () => {
    it('returns null (control mode uses pipes)', () => {
      const proxy = new ControlModeProxy(createOptions())
      expect(proxy.getClientTty()).toBeNull()
    })
  })

  describe('start()', () => {
    it('creates grouped session and spawns tmux -CC', async () => {
      const spawnSync = mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') }))
      const spawn = mock(() => createMockProcess())
      const options = createOptions({ spawn: spawn as any, spawnSync: spawnSync as any })
      const proxy = new ControlModeProxy(options)

      await proxy.start()

      expect(spawnSync).toHaveBeenCalledWith(
        ['tmux', 'new-session', '-d', '-t', 'agentboard', '-s', 'test-session'],
        expect.any(Object)
      )
      expect(spawn).toHaveBeenCalledWith(
        ['tmux', '-CC', 'attach', '-t', 'test-session'],
        expect.objectContaining({ stdout: 'pipe', stdin: 'pipe' })
      )
      expect(proxy.isReady()).toBe(true)
    })

    it('throws TerminalProxyError if session creation fails', async () => {
      const spawnSync = mock(() => ({ exitCode: 1, stdout: Buffer.from(''), stderr: Buffer.from('session error') }))
      const options = createOptions({ spawnSync: spawnSync as any })
      const proxy = new ControlModeProxy(options)

      await expect(proxy.start()).rejects.toMatchObject({
        code: 'ERR_SESSION_CREATE_FAILED',
        retryable: true
      })
    })
  })

  describe('write()', () => {
    it('sends send-keys command via tmux control mode', async () => {
      const mockStdin = {
        write: mock(() => 0)
      }
      const mockProcess = {
        stdin: mockStdin,
        stdout: new ReadableStream<Uint8Array>(),
        kill: mock(() => {}),
        exited: new Promise<void>(() => {})
      }
      const spawn = mock(() => mockProcess)
      const spawnSync = mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') }))
      const options = createOptions({ spawn: spawn as any, spawnSync: spawnSync as any })
      const proxy = new ControlModeProxy(options)

      await proxy.start()
      proxy.write('hello')

      expect(mockStdin.write).toHaveBeenCalled()
      const calls = mockStdin.write.mock.calls as unknown[][]
      const writeCall = calls[0] as unknown[]
      const written = writeCall[0] as string
      expect(written).toContain('send-keys')
      expect(written).toContain('hello')
    })
  })

  describe('resize()', () => {
    it('sends resize-pane command', async () => {
      const mockStdin = {
        write: mock(() => 0)
      }
      const mockProcess = {
        stdin: mockStdin,
        stdout: new ReadableStream<Uint8Array>(),
        kill: mock(() => {}),
        exited: new Promise<void>(() => {})
      }
      const spawn = mock(() => mockProcess)
      const spawnSync = mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') }))
      const options = createOptions({ spawn: spawn as any, spawnSync: spawnSync as any })
      const proxy = new ControlModeProxy(options)

      await proxy.start()
      proxy.resize(120, 40)

      expect(mockStdin.write).toHaveBeenCalled()
      const calls = mockStdin.write.mock.calls as unknown[][]
      const writeCall = calls[0] as unknown[]
      const written = writeCall[0] as string
      expect(written).toContain('resize-pane')
      expect(written).toContain('120')
      expect(written).toContain('40')
    })
  })

  describe('dispose()', () => {
    it('kills process and cleans up session', async () => {
      const mockProcess = createMockProcess()
      const spawn = mock(() => mockProcess)
      const spawnSync = mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') }))
      const options = createOptions({ spawn: spawn as any, spawnSync: spawnSync as any })
      const proxy = new ControlModeProxy(options)

      await proxy.start()
      await proxy.dispose()

      expect(mockProcess.kill).toHaveBeenCalled()
      expect(spawnSync).toHaveBeenCalledWith(
        ['tmux', 'kill-session', '-t', 'test-session'],
        expect.any(Object)
      )
      expect(proxy.isReady()).toBe(false)
    })
  })

  describe('event parsing', () => {
    it('calls onEvent for parsed control mode events', async () => {
      const onEvent = mock(() => {})
      const stdoutController = { current: null as ReadableStreamDefaultController<Uint8Array> | null }
      const stdout = new ReadableStream<Uint8Array>({
        start(controller) {
          stdoutController.current = controller
        }
      })
      const mockProcess = {
        stdin: {
          write: mock(() => 0)
        },
        stdout,
        kill: mock(() => {}),
        exited: new Promise<void>(() => {})
      }
      const spawn = mock(() => mockProcess)
      const spawnSync = mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') }))
      const options = createOptions({ spawn: spawn as any, spawnSync: spawnSync as any, onEvent })
      const proxy = new ControlModeProxy(options)

      await proxy.start()

      // Simulate tmux output
      const encoder = new TextEncoder()
      stdoutController.current!.enqueue(encoder.encode('%output %0 hello world\n'))

      // Allow async processing
      await new Promise(resolve => setTimeout(resolve, 10))

      expect(onEvent).toHaveBeenCalledWith({
        type: 'output',
        paneId: '0',
        data: 'hello world'
      })
    })
  })

  describe('flow control', () => {
    it('tracks paused panes from pause events', async () => {
      const onEvent = mock(() => {})
      const stdoutController = { current: null as ReadableStreamDefaultController<Uint8Array> | null }
      const stdout = new ReadableStream<Uint8Array>({
        start(controller) {
          stdoutController.current = controller
        }
      })
      const mockProcess = {
        stdin: {
          write: mock(() => 0)
        },
        stdout,
        kill: mock(() => {}),
        exited: new Promise<void>(() => {})
      }
      const spawn = mock(() => mockProcess)
      const spawnSync = mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') }))
      const options = createOptions({ spawn: spawn as any, spawnSync: spawnSync as any, onEvent })
      const proxy = new ControlModeProxy(options)

      await proxy.start()

      // Simulate pause event
      const encoder = new TextEncoder()
      stdoutController.current!.enqueue(encoder.encode('%pause %0\n'))

      await new Promise(resolve => setTimeout(resolve, 10))

      expect(onEvent).toHaveBeenCalledWith({
        type: 'pause',
        paneId: '0'
      })
    })
  })

  describe('pausePane() and resumePane()', () => {
    it('sends flow control commands', async () => {
      const mockStdin = {
        write: mock(() => 0)
      }
      const mockProcess = {
        stdin: mockStdin,
        stdout: new ReadableStream<Uint8Array>(),
        kill: mock(() => {}),
        exited: new Promise<void>(() => {})
      }
      const spawn = mock(() => mockProcess)
      const spawnSync = mock(() => ({ exitCode: 0, stdout: Buffer.from(''), stderr: Buffer.from('') }))
      const options = createOptions({ spawn: spawn as any, spawnSync: spawnSync as any })
      const proxy = new ControlModeProxy(options)

      await proxy.start()
      proxy.pausePane('%0')

      expect(mockStdin.write).toHaveBeenCalled()
      const calls = mockStdin.write.mock.calls as unknown[][]
      let writeCall = calls[0] as unknown[]
      let written = writeCall[0] as string
      expect(written).toContain('refresh-client')
      expect(written).toContain('pause')

      proxy.resumePane('%0')

      writeCall = calls[1] as unknown[]
      written = writeCall[0] as string
      expect(written).toContain('refresh-client')
      expect(written).toContain('continue')
    })
  })
})
