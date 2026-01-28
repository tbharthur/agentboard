// src/server/terminal/__tests__/ControlModeParser.test.ts

import { describe, expect, it } from 'bun:test'
import { ControlModeParser } from '../ControlModeParser'

describe('ControlModeParser', () => {
  describe('feed()', () => {
    it('returns empty array for empty input', () => {
      const parser = new ControlModeParser()
      expect(parser.feed('')).toEqual([])
    })

    it('buffers partial lines until newline received', () => {
      const parser = new ControlModeParser()
      expect(parser.feed('%output %0 hel')).toEqual([])
      expect(parser.feed('lo\n')).toEqual([
        { type: 'output', paneId: '0', data: 'hello' }
      ])
    })
  })

  describe('%output parsing', () => {
    it('parses basic output', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%output %0 hello world\n')
      expect(events).toEqual([
        { type: 'output', paneId: '0', data: 'hello world' }
      ])
    })

    it('decodes octal escapes', () => {
      const parser = new ControlModeParser()
      // \134 = backslash, \012 = newline
      const events = parser.feed('%output %0 foo\\134bar\\012baz\n')
      expect(events).toEqual([
        { type: 'output', paneId: '0', data: 'foo\\bar\nbaz' }
      ])
    })

    it('handles multi-digit pane IDs', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%output %123 test\n')
      expect(events).toEqual([
        { type: 'output', paneId: '123', data: 'test' }
      ])
    })
  })

  describe('%extended-output parsing', () => {
    it('parses extended output with latency', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%extended-output %0 500 : hello\n')
      expect(events).toEqual([
        { type: 'output', paneId: '0', data: 'hello', latencyMs: 500 }
      ])
    })
  })

  describe('%begin/%end/%error parsing', () => {
    it('parses begin event', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%begin 1706472000 42 1\n')
      expect(events).toEqual([
        { type: 'command-start', cmdNum: 42, timestamp: 1706472000, flags: 1 }
      ])
    })

    it('parses end event', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%end 1706472000 42 1\n')
      expect(events).toEqual([
        { type: 'command-end', cmdNum: 42, success: true }
      ])
    })

    it('parses error event', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%error 1706472000 42 1\n')
      expect(events).toEqual([
        { type: 'command-end', cmdNum: 42, success: false }
      ])
    })

    it('captures command output between begin and end', () => {
      const parser = new ControlModeParser()
      const events = parser.feed(
        '%begin 1706472000 42 1\n' +
        'line 1\n' +
        'line 2\n' +
        '%end 1706472000 42 1\n'
      )
      expect(events).toEqual([
        { type: 'command-start', cmdNum: 42, timestamp: 1706472000, flags: 1 },
        { type: 'command-output', cmdNum: 42, line: 'line 1' },
        { type: 'command-output', cmdNum: 42, line: 'line 2' },
        { type: 'command-end', cmdNum: 42, success: true }
      ])
    })
  })

  describe('window events parsing', () => {
    it('parses window-add', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%window-add @5\n')
      expect(events).toEqual([
        { type: 'window-add', windowId: '5' }
      ])
    })

    it('parses window-close', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%window-close @5\n')
      expect(events).toEqual([
        { type: 'window-close', windowId: '5' }
      ])
    })

    it('parses window-renamed', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%window-renamed @5 my-window\n')
      expect(events).toEqual([
        { type: 'window-renamed', windowId: '5', name: 'my-window' }
      ])
    })
  })

  describe('session events parsing', () => {
    it('parses session-changed', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%session-changed $3 my-session\n')
      expect(events).toEqual([
        { type: 'session-changed', sessionId: '3', name: 'my-session' }
      ])
    })
  })

  describe('flow control parsing', () => {
    it('parses pause', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%pause %0\n')
      expect(events).toEqual([
        { type: 'pause', paneId: '0' }
      ])
    })

    it('parses continue', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%continue %0\n')
      expect(events).toEqual([
        { type: 'continue', paneId: '0' }
      ])
    })
  })

  describe('exit parsing', () => {
    it('parses exit without reason', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%exit\n')
      expect(events).toEqual([
        { type: 'exit', reason: undefined }
      ])
    })

    it('parses exit with reason', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%exit server exited\n')
      expect(events).toEqual([
        { type: 'exit', reason: 'server exited' }
      ])
    })
  })

  describe('unknown messages', () => {
    it('ignores unknown % messages', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('%unknown-message foo bar\n')
      expect(events).toEqual([])
    })

    it('ignores non-% lines outside command context', () => {
      const parser = new ControlModeParser()
      const events = parser.feed('some random text\n')
      expect(events).toEqual([])
    })
  })

  describe('multiple events', () => {
    it('parses multiple events in single feed', () => {
      const parser = new ControlModeParser()
      const events = parser.feed(
        '%window-add @1\n' +
        '%output %0 hello\n' +
        '%window-renamed @1 test\n'
      )
      expect(events).toHaveLength(3)
      expect(events[0]).toEqual({ type: 'window-add', windowId: '1' })
      expect(events[1]).toEqual({ type: 'output', paneId: '0', data: 'hello' })
      expect(events[2]).toEqual({ type: 'window-renamed', windowId: '1', name: 'test' })
    })
  })
})
