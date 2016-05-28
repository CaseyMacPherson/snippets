#!/bin/bash
####################
#
# Version compare was pulled from
# http://stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format
####################
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}


if [ "$1" = "" ]
then
  echo "Enter the location of your ghost installation"
  read -p ": " installdirectory
else
  installdirectory=$1
fi

if [ ! -d "$installdirectory" ]
then
  echo "$installdirectory is not a directory"
  exit 1
fi

echo "Determining Latest version of Ghost"
allreleasesjson=$(curl -s https://api.github.com/repos/TryGhost/Ghost/releases)
ghostreleasejson=$(echo $allreleasesjson | jq '.[0] | { name: .name, zipurl: .zipball_url }')

#sed is used to strip the quotes
ghostversion=$(echo $ghostreleasejson | jq '.name' | sed -e 's/"//g')
echo "Release Version: $ghostversion"

ghostdownloadurl=$(echo $ghostreleasejson | jq '.zipurl' | sed -e 's/"//g')
echo "Download Url: $ghostdownloadurl"

installedversion=$(jq .version $installdirectory/package.json | sed -e 's/"//g')
echo "Your Version: $installedversion"

vercomp $ghostversion $installedversion

if [ "$?" -lt 1 ]
then
  echo "No upgrade required"
  exit 0
fi

echo "Upgrade from $installedversion to $ghostversion"

ghostoutputfile="ghost-latest.zip"
ghostbuild="$(pwd)/ghost_$ghostversion"

if [ ! -e $ghostbuild ]
then
  curl -LOk https://ghost.org/zip/ghost-latest.zip
  unzip  $ghostoutputfile -d $ghostbuild
fi

declare -a itemstoremove=("$installdirectory/core" "$installdirectory/*.json" "$installdirectory/*.md")

for item in $itemstoremove
do
  echo "Removing $item"
  if [ "$item" == "/" ] || [ "$item" == "/etc" ] || [ "$item" == "" ]
  then
    echo "Skipping $item because it's restricted"
    continue
  fi
  rm -rf $item
done

echo "Copying $ghostbuild/core to $installdirectory"
cp -r $ghostbuild/core $installdirectory/

cp $ghostbuild/index.js $installdirectory
cp $ghostbuild/*.md $installdirectory
cp $ghostbuild/*.json $installdirectory

echo "Updating Casper theme"
mv $installdirectory/content/themes/casper $installdirectory/content/themes/casper_$installedversion
cp -r $ghostbuild/content/themes/casper $installdirectory/content/themes
