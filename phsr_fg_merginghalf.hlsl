#include "phsr_common.hlsli"

//------------------------------------------------------- PARAMETERS
RWTexture2D<uint> motionReprojHalfTipX;
RWTexture2D<uint> motionReprojHalfTipY;
RWTexture2D<uint> motionReprojHalfTopX;
RWTexture2D<uint> motionReprojHalfTopY;

RWTexture2D<float2> motionReprojectedTip;
RWTexture2D<float2> motionReprojectedTop;

Texture2D<float2> currMotionUnprojected;
Texture2D<float2> prevMotionUnprojected;
Texture2D<float> currDepthTexture;
Texture2D<float> prevDepthTexture;

cbuffer shaderConsts : register(b0)
{
    float4x4 prevClipToClip;
    float4x4 clipToPrevClip;
    
    uint2 dimensions;
    float2 tipTopDistance;
    float2 viewportSize;
    float2 viewportInv;
}

SamplerState bilinearClampedSampler : register(s0);

#define TILE_SIZE 8

//------------------------------------------------------- ENTRY POINT
[shader("compute")]
[numthreads(TILE_SIZE, TILE_SIZE, 1)]
void main(uint2 groupId : SV_GroupID, uint2 localId : SV_GroupThreadID, uint groupThreadIndex : SV_GroupIndex)
{
    uint2 dispatchThreadId = localId + groupId * uint2(TILE_SIZE, TILE_SIZE);
    int2 currentPixelIndex = dispatchThreadId;
	
    float2 pixelCenter = float2(currentPixelIndex) + 0.5f;
    float2 viewportUV = pixelCenter * viewportInv;
    float2 screenPos = viewportUV;
	
    const float distanceFull = tipTopDistance.x + tipTopDistance.y;
    const float distanceHalfTip = tipTopDistance.x;
    const float distanceHalfTop = tipTopDistance.y;
	
    uint halfTipX = motionReprojHalfTipX[currentPixelIndex];
    uint halfTipY = motionReprojHalfTipY[currentPixelIndex];
    int2 halfTipIndex = int2(halfTipX & IndexLast13DigitsMask, halfTipY & IndexLast13DigitsMask);
    bool bIsHalfTipUnwritten = any(halfTipIndex == UnwrittenIndexIndicator);
    float2 motionVectorHalfTip = prevMotionUnprojected[halfTipIndex] * viewportInv;
    float2 samplePosHalfTip = screenPos + motionVectorHalfTip * distanceHalfTip;
    float2 motionCaliberatedUVHalfTip = samplePosHalfTip;
    motionCaliberatedUVHalfTip = clamp(motionCaliberatedUVHalfTip, float2(0.0f, 0.0f), float2(1.0f, 1.0f));
    float2 motionHalfTipCaliberated = prevMotionUnprojected.SampleLevel(bilinearClampedSampler, motionCaliberatedUVHalfTip, 0) * viewportInv;
    if (all(abs(motionHalfTipCaliberated) < viewportInv))
    {
        motionHalfTipCaliberated = -ComputeStaticVelocityTopTip(screenPos, prevDepthTexture.SampleLevel(bilinearClampedSampler, motionCaliberatedUVHalfTip, 0).r, prevClipToClip);
    }
	
    uint halfTopX = motionReprojHalfTopX[currentPixelIndex];
    uint halfTopY = motionReprojHalfTopY[currentPixelIndex];
    int2 halfTopIndex = int2(halfTopX & IndexLast13DigitsMask, halfTopY & IndexLast13DigitsMask);
    bool bIsHalfTopUnwritten = any(halfTopIndex == UnwrittenIndexIndicator);
    float2 motionVectorHalfTop = currMotionUnprojected[halfTopIndex] * viewportInv;
    float2 samplePosHalfTop = screenPos - motionVectorHalfTop * distanceHalfTop;
    float2 motionCaliberatedUVHalfTop = samplePosHalfTop;
    motionCaliberatedUVHalfTop = clamp(motionCaliberatedUVHalfTop, float2(0.0f, 0.0f), float2(1.0f, 1.0f));
    float2 motionHalfTopCaliberated = currMotionUnprojected.SampleLevel(bilinearClampedSampler, motionCaliberatedUVHalfTop, 0) * viewportInv;
    if (bIsHalfTopUnwritten)
    {
        motionHalfTopCaliberated = float2(0.0f, 0.0f) + float2(ImpossibleMotionOffset, ImpossibleMotionOffset);
    }
	
	{
        bool bIsValidhistoryPixel = all(uint2(currentPixelIndex) < dimensions);
        if (bIsValidhistoryPixel)
        {
            motionReprojectedTip[currentPixelIndex] = motionHalfTipCaliberated;
            motionReprojectedTop[currentPixelIndex] = motionHalfTopCaliberated;
        }
    }
}