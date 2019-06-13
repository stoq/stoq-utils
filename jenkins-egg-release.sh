# generate egg artifacts if the build was triggered by
# the merge of a gerrit change that updates the
# version of the project
echo "experimental build step, to generate eggs and a git tag whenever a plugin version change is merged"
source venv/bin/activate
source stoq/utils/env.sh
cd $plugin_name

echo $GERRIT_EVENT_TYPE

if [ "$plugin_name" = "stoq-plugin-nfe" ]; then
  VERSION_FILE="stoqnfe/nfce.plugin"
  VERSION=`grep "^Version=\(.*\)" "$VERSION_FILE" | sed "s/.*=//g"`
elif [ "$plugin_name" = "stoq-plugin-cat" ]; then
  VERSION_FILE="stoqcat/cat.plugin"
  VERSION=`grep "^Version=\(.*\)" "$VERSION_FILE" | sed "s/.*=//g"`
else
  SHORT_PLUGIN_NAME=`echo $plugin_name | sed s/stoq-plugin-//g`
  if [ SHORT_PLUGIN_NAME != "" ]; then
    VERSION_FILE="stoq"$SHORT_PLUGIN_NAME"/"$SHORT_PLUGIN_NAME".plugin"
    VERSION=`grep "^Version=\(.*\)" "$VERSION_FILE" | sed "s/.*=//g"`
  else
    VERSION_FILE="setup.py"
    VERSION=`grep "version=\"" setup.py |sed -e "s/.*=\"//g" -e "s/\".*//g"`
  fi
fi

if [ -z "$GERRIT_EVENT_TYPE" ]; then
  echo "This is a manual build, generate an alpha egg."
    MANUAL_BUILD=true
    GIT_HASH=`git log --pretty=format:'%h' -n 1`
  sed -e"s/version=\".*/version=\"$VERSION-alpha-$GIT_HASH\",/g" -i setup.py
fi

if [ $GERRIT_EVENT_TYPE = "change-merged" ]; then
    # sat plugin is failing compilation, ignore the debugs
    if [ $plugin_name = "stoq-plugin-sat" ]; then
      echo "sat plugin"
      sed -i -e"s/ -o/ --verbose -o/g" Makefile
      env
      uname -a
      hostname
      ip a
  fi

    git show

    # check if last change modified a version line
    VERSION_LINES=$(git show | grep -i "[^q]version=")
    if [ -n "$VERSION_LINES" ]; then
        echo "Plugin version changed to $VERSION"
        VERSION_CHANGED=true
        echo "VERSION_CHANGED=$VERSION_CHANGED"

    # create git tag
        if `git tag -a "$VERSION" -m "New release"`;then
          echo 'new tag created'
          git push origin --tags
        else
          echo 'ERROR creating tag (tag exists already? should we exit?) For now, create the egg for the existing tagged commit'
          git checkout "$VERSION"
        fi
        git show

    fi
fi

if [[ ($VERSION_CHANGED = true || $MANUAL_BUILD = true) ]]; then
  if [ $plugin_name = "stoq-plugin-sat" ]; then
    make stoqsat/utils/stoq_sat
  fi
  make plugin-egg
  ls dist
else
  echo "Version didn't change, no need for making an egg."
    echo "VERSION_CHANGED=$VERSION_CHANGED MANUAL_BUILD=$MANUAL_BUILD"
  exit 0
fi
