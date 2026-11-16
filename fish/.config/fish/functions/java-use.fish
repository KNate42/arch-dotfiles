# switch the default Java version: java-use 21
# This work made by Anfinogentov Nikita

function java-use --description 'Switch default JDK through archlinux-java'
    if test (count $argv) -eq 0
        archlinux-java status
        return 0
    end
    set -l wanted java-$argv[1]-openjdk
    if not archlinux-java status | string match -q "*$wanted*"
        echo "Ooops.. no $wanted installed"
        return 1
    end
    sudo archlinux-java set $wanted
end
