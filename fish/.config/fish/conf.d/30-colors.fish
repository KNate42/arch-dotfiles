# fish syntax colors from the matugen palette
# This work made by Anfinogentov Nikita

# Здесь я беру файл, который пишет matugen; его нет — остаются цвета fish
set -l palette_file $HOME/.cache/matugen/fish-colors.fish
if test -r $palette_file
    source $palette_file
end
