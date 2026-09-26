#!/usr/bin/env bash
# Устанавливает скилл watch для Claude Code и проверяет зависимости.
#   ./install.sh          скопировать скилл в ~/.claude/skills/watch и проверить зависимости
#   ./install.sh --check  только проверить зависимости
#   ./install.sh --deps   то же, что по умолчанию, и доустановить недостающее (brew / pipx)
#   ./install.sh --force  перезаписать существующую папку без вопроса
# Другая папка скиллов: CLAUDE_SKILLS_DIR=/путь ./install.sh
set -e

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST="$SKILLS_DIR/watch"
MODE="install"
FORCE=0
DEPS=0

for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --deps)  DEPS=1 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Неизвестный параметр: $arg (см. ./install.sh --help)"; exit 1 ;;
  esac
done

say() { printf '%s\n' "$*"; }

# 1. Копирование скилла
if [ "$MODE" = "install" ]; then
  if [ "$SRC" = "$DEST" ]; then
    say "Скилл уже лежит в $DEST"
  else
    if [ -e "$DEST" ] && [ "$FORCE" -ne 1 ]; then
      printf 'Папка %s уже существует. Перезаписать файлы? [y/N] ' "$DEST"
      read -r answer
      case "$answer" in
        y|Y|yes|YES) ;;
        *) say "Отменено, ничего не изменено."; exit 1 ;;
      esac
    fi
    mkdir -p "$DEST"
    (cd "$SRC" && tar --exclude='.git' -cf - .) | (cd "$DEST" && tar -xf -)
    say "Скилл скопирован в $DEST"
  fi
fi

# 2. Зависимости
OS="$(uname -s)"
say ""
say "Зависимости:"
missing=""
for tool in yt-dlp ffmpeg whisper; do
  if command -v "$tool" >/dev/null 2>&1; then
    say "  ok    $tool"
  else
    say "  НЕТ   $tool"
    missing="$missing $tool"
  fi
done

if [ -z "$missing" ]; then
  say ""
  say "Всё на месте. Перезапустите Claude Code и напишите: посмотри видео <ссылка>"
  exit 0
fi

say ""
say "Не хватает:$missing"
say "Команды установки:"

run() { say "> $*"; "$@"; }

if [ "$OS" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    say "  Нужен Homebrew: https://brew.sh (после установки запустите скрипт снова)"
    exit 1
  fi
  pkgs=""
  for t in $missing; do
    case "$t" in
      whisper) pkgs="$pkgs openai-whisper" ;;
      *) pkgs="$pkgs $t" ;;
    esac
  done
  say "  brew install$pkgs"
  if [ "$DEPS" -eq 1 ]; then
    # shellcheck disable=SC2086
    run brew install $pkgs
  fi
else
  apt_pkgs=""
  pipx_pkgs=""
  for t in $missing; do
    case "$t" in
      ffmpeg) apt_pkgs="$apt_pkgs ffmpeg" ;;
      yt-dlp) pipx_pkgs="$pipx_pkgs yt-dlp" ;;
      whisper) pipx_pkgs="$pipx_pkgs openai-whisper" ;;
    esac
  done
  if ! command -v pipx >/dev/null 2>&1 && [ -n "$pipx_pkgs" ]; then
    apt_pkgs="$apt_pkgs pipx"
  fi
  if [ -n "$apt_pkgs" ]; then say "  sudo apt install$apt_pkgs"; fi
  for p in $pipx_pkgs; do say "  pipx install $p"; done
  if [ "$DEPS" -eq 1 ]; then
    # shellcheck disable=SC2086
    if [ -n "$apt_pkgs" ]; then run sudo apt install -y $apt_pkgs; fi
    for p in $pipx_pkgs; do run pipx install "$p"; done
  fi
fi

if [ "$DEPS" -ne 1 ]; then
  say ""
  say "Выполните команды выше сами или запустите: ./install.sh --deps"
else
  say ""
  say "Готово. Перезапустите Claude Code и напишите: посмотри видео <ссылка>"
fi
