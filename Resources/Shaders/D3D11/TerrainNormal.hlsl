/* 
 * ============================================================
 * Copyright (C) Christian Hamm. All Rights Reserved.
 * ============================================================
 */
#include "NormalMap.hlsl"
#include "TerrainUtility.hlsl"

cbuffer cb_TerrainPS
{
    float4   gDiffuseMtrl;
    float4   gEmissiveMtrl;
    float4   gEnvMtrl;
    bool     gHasNormalMap;
    bool     gHasSpecularMap;
    bool     gHasEmissiveMap;
    bool     gHasTexture;
    bool     gHasEnvMap;
    bool     gHasPrecomputedLighting;
    float    gTime;
};

Texture2D t0 : register(t0);
Texture2D t1 : register(t1);
Texture2D t2 : register(t2);
Texture2D t3 : register(t3);
Texture2D t4 : register(t4);
TextureCube t5 : register(t5);


sampler s0 : register(s0);
sampler s1 : register(s1);
sampler s2 : register(s2);
sampler s3 : register(s3);
sampler s4 : register(s4);
sampler s5 : register(s5);


struct VSOutputTerrain
{
    float4 posH : SV_Position;
    float2 depth : TEXCOORD0;
    float2 tex : TEXCOORD1;
    float3 biNormal : TEXCOORD2;
    float4 tangent : TEXCOORD3;
    float3 texVertex : TEXCOORD4;
    float painterAlpha : TEXCOORD5;
    float3 color : COLOR0;
    float3 colorLighting : COLOR1;
    float3 colorEmissive : COLOR2;
};

struct PSOutput
{
    float4 RT1 : SV_Target0;
    float4 RT2 : SV_Target1;
    float4 RT3 : SV_Target2;
    float3 RT4 : SV_Target3;
};


VSOutputTerrain VS(float3 pos : POSITION0,
                   float3 tangent : TANGENT0,
                   float3 biNormal : BINORMAL0,
                   float2 tex0 : TEXCOORD0,
                   float4 color : COLOR0,
                   float4 colorLighting : COLOR1,
                   float4 colorEmissive : COLOR2)
{
    VSOutputTerrain outVS = (VSOutputTerrain) 0;

    outVS.texVertex = pos.xyz;
    outVS.posH = mul(float4(outVS.texVertex, 1.0f), gViewProjection);
    outVS.depth.xy = outVS.posH.zw;
    outVS.tex = tex0;
    outVS.biNormal = biNormal;
    outVS.tangent.xyz = tangent;
    outVS.color = color.rgb;
    outVS.painterAlpha = color.a;
    outVS.colorLighting = colorLighting.rgb * colorLighting.a;
    outVS.colorEmissive = colorEmissive.rgb * colorEmissive.a;

    return outVS;
}

PSOutput PS(VSOutputTerrain input)
{
    float3 normal = float3(0.0f, 0.0f, -1.0f);

    normal = SampleNormalMap(normal, input.biNormal, input.tangent.xyz, t1, s1, input.tex.xy);
    normal = normalize(mul(float4(normal, 0), gView).xyz);

    float4 diff = float4(input.color, 1.0f) * t0.Sample(s0, input.tex.xy);

    diff.rgb *= gDiffuseMtrl.rgb;

    if (diff.a <= 0.1)
        discard;

    float spec = 0.0;

    if (gHasSpecularMap)
    {
        spec = t2.Sample(s2, input.tex.xy).r;
    }

    float painter = t4.Sample(s4, input.texVertex.xy * 0.001).r * input.painterAlpha * 4;
    
    spec += painter;

    if (painter > 0.2)
        diff.a = 0.7;

    float3 emissive = float3(0.0, 0.0, 0.0);

    if (gHasEmissiveMap)
    {
        emissive.rgb = input.colorEmissive * gEmissiveMtrl.rgb * t3.Sample(s3, input.tex.xy).rgb;
    }

    if (gHasPrecomputedLighting)
    {
        float4 sampledColor = t0.Sample(s0, input.tex.xy).rgba;
        
        emissive.rgb += sampledColor.rgb* input.colorLighting;
    }

    /*float3 viewSurfacePos = mul(float4(input.texVertex, 1.0), gView).xyz;
    float3 viewSurfaceRay = normalize(-viewSurfacePos);
    float3 viewReflectedRay = reflect(viewSurfaceRay, normal.xyz);
    viewReflectedRay.y *= -1.0;
    float3 reflectedLighting = input.colorLighting * t5.Sample(s5, viewReflectedRay).rgb;

    float t = 1.0 - saturate(input.texVertex.z / 800);
    emissive.rgb += 2 * lerp(float3(0,0,0), reflectedLighting * gEnvMtrl.rgb, 1 * t * spec * gEnvMtrl.a);*/

    PSOutput outPS;
    outPS.RT1 = float4(diff.rgba);
    outPS.RT2 = float4(normal, dot(input.color, float3(0.2125f, 0.7154f, 0.0721f)) * spec.r * 10);
    outPS.RT3 = float4(input.depth.x / input.depth.y, 0, 0, 0);
    outPS.RT4 = float3(emissive.rgb);

    return outPS;
}
