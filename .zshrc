# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="/Users/jsrn/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

export EDITOR='code --wait'

# SYSTEM UTILITIES
alias please='sudo $(fc -ln -1)'
alias ipaddr="ifconfig | grep 192 | cut -d ' ' -f 2"
alias nuke='shred -u'
alias shconfig='code ~/.zshrc'
alias whatismyip="ifconfig | grep 192 | cut -d ' ' -f 2"
alias hosts="cat ~/.ssh/config | grep 'Host ' -A 1 | sed 's/    Hostname/Hostname/' | cut -d ' ' -f 2"

# GIT
alias gcane='git commit --amend --no-edit'
alias gclean='CURR=`git branch --show-current --no-color`;git branch --merged | egrep -v "(^\*|$CURR)" | xargs git branch -d'
alias pickaxe="git log -p -S"
alias gl='git log --pretty=reference --no-merges'
alias git-latest-tag="git tag --list | tac | head -1"

# OTHER
alias blog='cd ~/code-personal/jsrn.github.io && bundle exec jekyll serve --drafts --future'

function valec() {
    pbpaste > /tmp/valeclip
    vale --no-wrap --config /Users/jsrn/.vale.ini /tmp/valeclip
    rm /tmp/valeclip
}

export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
export REVEAL_RUBOCOP_TODO=1

# Anything above this line should be stuff that I want on basically any system.
# System specific changes should go after this line to avoid being overwritten.

source ~/.zshrc-work
