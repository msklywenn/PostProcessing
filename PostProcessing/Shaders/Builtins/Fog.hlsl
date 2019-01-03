#ifndef UNITY_POSTFX_FOG
#define UNITY_POSTFX_FOG

half4 _FogColor;
half4 _FogParams;

samplerCUBE _SkyCubemap;

#define FOG_DENSITY _FogParams.x
#define FOG_START _FogParams.y
#define FOG_END _FogParams.z
#define FOG_SKYBOX_ROTATION _FogParams.w

half ComputeFog(float z)
{
    half fog = 0.0;
#if FOG_LINEAR
    fog = (FOG_END - z) / (FOG_END - FOG_START);
#elif FOG_EXP
    fog = exp2(-FOG_DENSITY * z);
#else // FOG_EXP2
    fog = FOG_DENSITY * z;
    fog = exp2(-fog * fog);
#endif
    return saturate(fog);
}

float ComputeFogDistance(float depth)
{
    float dist = depth * _ProjectionParams.z;
    dist -= _ProjectionParams.y;
    return dist;
}

float3 RotateAroundYAxis(float3 v, float rad)
{
    float alpha = rad;
    float sina, cosa;
    sincos(alpha, sina, cosa);
    float2x2 m = float2x2(cosa, -sina, sina, cosa);
    return float3(mul(m, v.xz), v.y).xzy;
}

#endif // UNITY_POSTFX_FOG
