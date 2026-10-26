import { expect, test } from 'claude-code/testing'

const env: Record<string, string> = {
  CLAUDE_CONFIG_DIR: 'C:\\Users\\me\\.claude-accounts\\work',
  USERPROFILE: 'C:\\Users\\me',
}

test('the status line and /account name the account ca started', async ($, on) => {
  const status: (string | undefined)[] = []
  on('env.get', (_, e) => ({ value: env[e.name] }))
  on('session.identity', () => ({ value: { kind: 'claude.ai', email: 'me@work.example', isVerified: true } }))
  on('ui.status', (_, e) => {
    status.push(e.text)

    return { value: undefined }
  })
  on('command.register', () => ({ value: { command: 'account' } }))
  on('fs.list', () => ({
    value: [
      { name: 'work', kind: 'directory', size: 0, mtimeMs: 0, isLink: false },
      { name: 'personal', kind: 'directory', size: 0, mtimeMs: 0, isLink: false },
    ],
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  expect(status.at(-1)).toBe('account: work · me@work.example')

  const out = await $.command.run({ command: 'account', args: '' })
  expect(out.text).toContain('Accounts: main, work (this one), personal.')
})
