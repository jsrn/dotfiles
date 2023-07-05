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

export KUBE_EDITOR='code --wait'
export EDITOR='code --wait'

eval "$(rbenv init -)"

# system utilities
alias please='sudo $(fc -ln -1)'
alias ipaddr="ifconfig | grep 192 | cut -d ' ' -f 2"
alias nuke='shred -u'
alias shconfig='code ~/.zshrc'
alias whatismyip="ifconfig | grep 192 | cut -d ' ' -f 2"
alias hosts="cat ~/.ssh/config | grep 'Host ' -A 1 | sed 's/    Hostname/Hostname/' | cut -d ' ' -f 2"

# kubernetes
alias k='kubectl'
alias kx='kubectl exec'
alias kontext='kubectx'

# docker
alias dsh='docker compose run --rm web bash'
alias dcu='docker compose up'
alias dcub='docker compose up --build'

# git
alias gcane='git commit --amend --no-edit'
alias gclean='CURR=`git branch --show-current --no-color`;git branch --merged | egrep -v "(^\*|$CURR)" | xargs git branch -d'
alias pickaxe="git log -p -S"
alias gl='git log --pretty=reference --no-merges'
alias git-latest-tag="git tag --list | tac | head -1"

# other
alias tf='terraform'

export PATH="$HOME/.fastlane/bin:$HOME/bin:$HOME/apache-maven-3.8.3/bin:$PATH"
export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools

# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/__tabtab.zsh ]] && . ~/.config/tabtab/__tabtab.zsh || true

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Anything above this line should be stuff that I want on basically any system.
# System specific changes should go after this line to avoid being overwritten.
