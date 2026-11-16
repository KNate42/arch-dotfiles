# fish shell entry point; real settings live in conf.d
# This work made by Anfinogentov Nikita

if status is-interactive
    set -g fish_greeting
    starship init fish | source
end
