varying highp vec4 var_position;
varying mediump vec3 var_normal;
varying mediump vec2 var_texcoord0;
varying highp vec4 var_color0;
varying mediump vec4 var_light;
varying mediump vec4 var_data; //x:power of light(1-fraction) y:startDrawFraction z:fixedPower or <0 if not fixed power

uniform lowp sampler2D tex0;
uniform lowp vec4 tint;
uniform lowp vec4 ambient;


void main()
{
    vec4 color0 = vec4(var_color0.rgb,var_color0.a);
    float fixedPower = step(0.0, var_data.z);
    float startPower = step(var_data.y, 1.0-var_data.x);
    float scale = startPower * (var_data.x * (1.0-fixedPower) + var_data.z * fixedPower);
    vec4 color = color0 * scale;
    //gamma correction
   //color = sqrt(color);
    gl_FragColor =color;

}

