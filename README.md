# 💧 chuchu

Tints your terminal background by where you are.<br>
Like a Chuchu, it takes on a different color depending on where it lives.

When you step into a pod, a container or a remote host, the pane's background
turns a color derived from that name, and goes back once you return to the prompt.
The same name always gets the same color, so you learn to recognise places at a glance.

## Supported commands

| Command | Colored by |
| --- | --- |
| `kubectl exec` | pod name |
| `docker exec` / `docker container exec` / `docker compose exec` | container / service name |
| `ssh` | host name (user and port are ignored) |

Aliases such as `alias k=kubectl` work as they are.
Only the first command of a line is looked at, so `ssh host | tee log` is tinted but `cd x && ssh host` is not.

## Requirements

- A terminal that supports setting the background color with OSC 11 and resetting it with OSC 111.
- A dark color theme. The default colors are dark tints and would stand out harshly on a light background.

## Installation

### Manual installation

```sh
git clone https://github.com/kiki-ki/chuchu.git ~/.zsh/chuchu
echo "source ~/.zsh/chuchu/chuchu.plugin.zsh" >> ~/.zshrc
```

### Plugin Managers

Chuchu follows the [Zsh Plugin Standard](https://wiki.zshell.dev/community/zsh_plugin_standard).
Install it with your favorite plugin manager (Sheldon, zinit, antidote, etc.) by referencing `kiki-ki/chuchu`.

## Usage

There is nothing to run: once loaded, it works on its own.

- `chuchu preview [name...]` - Show each palette color, or each given name's color, as the real background (any key: next, `q`: quit)
- `chuchu color <name>` - Print the color a name maps to
- `chuchu version` - Show version
- `chuchu help` - Show help

To try it without touching your `~/.zshrc`, run `zsh try.zsh` in this repository.

## Configuration

### Colors

`CHUCHU_COLORS` is the palette a name is hashed into. Set it in your `~/.zshrc` to replace it.

```zsh
CHUCHU_COLORS=('#3b1111' '#113b11' '#11113b')
```

Setting it to an empty array turns tinting off.

The default is 12 dark colors picked in [OKLCH](https://oklch.com/) (L=0.26, C=0.06, hues 30° apart),
so text stays equally readable on every color and does not depend on your theme, as long as it is a dark one.
A dark background that keeps text readable leaves room for only about 12 colors whose neighbours
still look different; adding more mostly adds look-alikes rather than fewer collisions.

### Other commands

`CHUCHU_PARSERS` maps a command name to a function that sets `REPLY` to the target.
The function receives the command's arguments; leave `REPLY` empty to skip tinting.
Add entries after the plugin is loaded.

```zsh
.my_parse_mosh() { REPLY=${1#*@} }
CHUCHU_PARSERS[mosh]=.my_parse_mosh
```

## Development

```sh
zsh tests/chuchu.test.zsh  # unit tests
zsh tests/e2e.test.zsh     # drives a real interactive zsh through a pseudo-terminal
```

## License

MIT License
