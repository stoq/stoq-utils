set _DIRNAME (dirname (status --current-filename))
#Check if script is in a submodule. If it is, it should go up twice to
# get to the root. Otherwise, it should just go once.
if test -f "$_DIRNAME/../.gitmodules";
    set _DIRNAME $_DIRNAME/../..
else
    set _DIRNAME $_DIRNAME/..
end

set _CHECKOUT (readlink -f $_DIRNAME)
set OLD_PATH "$PATH"-
set OLD_PYTHONPATH "$PYTHONPATH"

for _PROJECT in (command ls $_CHECKOUT | command sort);
    set _PROJECT_PATH "$_CHECKOUT/$_PROJECT"
    #add new hooks every time the shell inits
    if test -d "$_PROJECT_PATH/utils/git-hooks/";
        command cp -au $_PROJECT_PATH/utils/git-hooks/* \
        $_PROJECT_PATH/.git/hooks/
    end

    # Put all projects inside checkout on PYTHONPATH and the ones having
    #  a bin directory on PATH
    set PYTHONPATH "$_PROJECT_PATH:$PYTHONPATH"
    if test -d "$_PROJECT_PATH/bin";
        set PATH "$_PROJECT_PATH/bin:$PATH"
	end
end

set -x PATH $PATH
set -x PYTHONPATH $PYTHONPATH
