#Resave tileset and all maps
#NEED when tileset changed
#https://github.com/mapeditor/tiled/commit/72789ab0e1a42c87f196f027f2cb6169675f5e48
mkdir -p ./editor/lua
rm -r ./editor/lua/*

#replace path to tiled
#TILED_PATH="/C/Program\ Files/Tiled/tiled.exe"

echo resave tilesets;
/C/Program\ Files/Tiled/tiled.exe --export-map --embed-tilesets lua tilesets/tilesets.tmx ./tilesets/tilesets.lua

echo resave maps;

for f in $(find ./editor/sources -name '*.tmx'); do
	fname=`basename $f`
	newname=${fname%.*}.lua
	echo $f;
	/C/Program\ Files/Tiled/tiled.exe --export-map lua $f ./editor/lua/$newname
done;

read -t 3 -p "Press any key or wait 3 second"