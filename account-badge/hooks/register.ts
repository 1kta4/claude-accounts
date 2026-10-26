import type { EngineInterface, Register } from 'claude-code'

// ca keeps every extra account in ~/.claude-accounts/<name>.
const ACCOUNTS_FOLDER = '.claude-accounts'

async function accountName($: EngineInterface) {
  const dir = await $.env.get('CLAUDE_CONFIG_DIR')

  if (!dir) {
    return 'main'
  }

  const parts = dir.split(/[\\/]+/).filter(Boolean)
  const at = parts.lastIndexOf(ACCOUNTS_FOLDER)

  return at >= 0 && at + 1 < parts.length ? parts[at + 1] : dir
}

async function email($: EngineInterface) {
  const who = await $.session.identity()

  return who.deny === undefined ? who.email : undefined
}

async function otherAccounts($: EngineInterface) {
  const home = (await $.env.get('USERPROFILE')) ?? (await $.env.get('HOME'))

  if (!home) {
    return []
  }

  const entries = await $.fs.list(`${home}/${ACCOUNTS_FOLDER}`).catch(() => [])

  return entries.filter(entry => entry.kind === 'directory').map(entry => entry.name)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'account',
      description: 'Show which Claude account this session uses, and how to switch',
    })
    const name = await accountName($)
    const address = await email($)
    $.ui.status(`account: ${name}${address ? ` · ${address}` : ''}`)

    return next(e)
  })

  on('command.run', { command: 'account' }, async $ => {
    const name = await accountName($)
    const address = await email($)
    const all = ['main', ...(await otherAccounts($))]

    return {
      text: [
        `This session: ${name}${address ? ` (${address})` : ''}.`,
        `Accounts: ${all.map(one => (one === name ? `${one} (this one)` : one)).join(', ')}.`,
        'To switch: /exit, then run `ca <account>` (add -c to continue that account\'s last chat),',
        'or open the "Claude (<account>)" shortcut in the Start menu.',
      ].join('\n'),
    }
  })
}
