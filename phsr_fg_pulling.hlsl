#include "phsr_common.hlsli"

//------------------------------------------------------- PARAMETERS
Texture2D<float2> motionVectorFiner;
Texture2D<float> motionReliabilityFiner;

RWTexture2D<float2> motionVectorCoarser;
RWTexture2D<float> motionReliabilityCoarser; //This is coarse too

cbuffer shaderConsts : register(b0)
{
    uint2 FinerDimension;
    uint2 CoarserDimension;
}

#define TILE_SIZE 8

//------------------------------------------------------- ENTRY POINT
[shader("compute")]
[numthreads(TILE_SIZE, TILE_SIZE, 1)]
void main(uint2 groupId : SV_GroupID, uint2 localId : SV_GroupThreadID, uint groupThreadIndex : SV_GroupIndex)
{
    uint2 dispatchThreadId = localId + groupId * uint2(TILE_SIZE, TILE_SIZE);
    int2 coarserPixelIndex = dispatchThreadId;
    
    int2 finerPixelUpperLeft = 2 * coarserPixelIndex;
    float2 filteredVector = 0.0f;
    float perPixelWeight = 0.0f;
    {
        for (int i = 0; i < subsampleCount4PointTian; ++i)
        {
            int2 finerIndex = finerPixelUpperLeft + subsamplePixelOffset4PointTian[i];
            float2 finerVector = motionVectorFiner[finerIndex];
            float finerWeight = motionReliabilityFiner[finerIndex];
            filteredVector += finerVector * finerWeight;
            perPixelWeight += finerWeight;
        }
        float normalization = SafeRcp(float(subsampleCount4PointTian));
        filteredVector *= normalization;
        perPixelWeight *= normalization;
    }
    
    {
        bool bIsValidhistoryPixel = all(uint2(coarserPixelIndex) < CoarserDimension);
        if (bIsValidhistoryPixel)
        {
            motionVectorCoarser[coarserPixelIndex] = filteredVector;
            motionReliabilityCoarser[coarserPixelIndex] = perPixelWeight;
        }
    }
}
