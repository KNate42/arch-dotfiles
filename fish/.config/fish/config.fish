# fish shell entry point; real settings live in conf.d
# This work made by Anfinogentov Nikita

if status is-interactive
    set -g fish_greeting
    # Здесь я показываю сводку о системе только в первом терминале сеанса, а не в каждом новом окне
    set -l greeted "$XDG_RUNTIME_DIR/dots-greeted"
    if command -q fastfetch; and test -n "$XDG_RUNTIME_DIR"; and not test -e "$greeted"
        touch "$greeted"
        fastfetch
    end
    starship init fish | source
end
