# Show fastfetch only in the first terminal of a login session.
# The marker lives in $XDG_RUNTIME_DIR, which is wiped at logout.
function rice_first_fetch
    set -l marker $XDG_RUNTIME_DIR/rice-ff-shown
    if not test -e $marker
        touch $marker
        fastfetch
    end
end
