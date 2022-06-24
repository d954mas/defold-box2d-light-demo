varying mediump vec2 var_texcoord0;

uniform lowp sampler2D texture_sampler;
uniform lowp vec4 tint;

void main()
{
    // Pre-multiply alpha since all runtime textures already are

    vec4 color = texture2D(texture_sampler, var_texcoord0.xy);
   // color.rgb = color.rgb * color.a;
    gl_FragColor = color;
}
