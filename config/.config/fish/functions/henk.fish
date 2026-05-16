function henk --description "Interactive hyprshutdown power menu"
    if not command -q hyprshutdown
        echo "hyprshutdown is not installed or not in PATH."
        return 127
    end

    printf '\nPower menu\n'
    printf '  1    reboot\n'
    printf '  0    shutdown\n'
    printf '  Esc  cancel\n\n'
    printf 'Choose: '

    set choice (bash -c 'IFS= read -rsn1 key; printf "%s" "$key"')
    printf '\n'

    switch "$choice"
        case 1
            command hyprshutdown -p reboot
        case 0
            command hyprshutdown -p "shutdown now"
        case \e
            echo "Canceled."
            return 0
        case '*'
            echo "Canceled."
            return 1
    end
end
