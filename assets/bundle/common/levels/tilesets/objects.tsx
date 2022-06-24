<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.8" tiledversion="1.8.2" name="objects" tilewidth="105" tileheight="150" tilecount="2" columns="0">
 <grid orientation="orthogonal" width="1" height="1"/>
 <tile id="0">
  <properties>
   <property name="player" type="bool" value="true"/>
  </properties>
  <image width="105" height="150" source="objects/player.png"/>
 </tile>
 <tile id="1">
  <properties>
   <property name="angle_begin" type="float" value="0"/>
   <property name="angle_end" type="float" value="360"/>
   <property name="color" type="color" value="#a8ffffff"/>
   <property name="distance" type="float" value="200"/>
   <property name="light" type="bool" value="true"/>
   <property name="rays" type="int" value="30"/>
   <property name="rays_dynamic" type="int" value="90"/>
   <property name="rotation_speed" type="float" value="0"/>
   <property name="static" type="bool" value="false"/>
  </properties>
  <image width="64" height="64" source="objects/light.png"/>
 </tile>
</tileset>
