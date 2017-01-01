/**
 * Copyright © 2016 Caroline Begbie. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include <metal_stdlib>
using namespace metal;

struct Constants {
  float4x4 modelViewProjectionMatrix;
  float4x4 shadowViewProjectionMatrix;
};

struct Vertex {
  float4 position;
};

struct VertexOut {
  float4 position [[position]];
  float4 shadowPosition;
};

vertex VertexOut vertex_shader(device Vertex *vertices [[buffer(0)]],
                            constant Constants &constants [[buffer(1)]],
                            uint vertexId [[vertex_id]]) {
  Vertex vertexIn = vertices[vertexId];
  VertexOut vertexOut;
  vertexOut.position = constants.modelViewProjectionMatrix * vertexIn.position;
  vertexOut.shadowPosition = constants.shadowViewProjectionMatrix * vertexIn.position;
  return vertexOut;
}

fragment half4 fragment_shader(VertexOut vertexIn [[stage_in]],
                               depth2d<float> shadow_texture [[texture(0)]]) {
  
  constexpr sampler shadow_sampler(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);

  float4 color;
  float2 xy = vertexIn.shadowPosition.xy / vertexIn.shadowPosition.w;
  
  // reposition between 0 and 1 for texture sampling
  xy = xy * 0.5 + 0.5;
  
  // sample is the wrong way up
  xy.y = 1 - xy.y;

  float bias = 0.001;
  float shadow_sample = shadow_texture.sample(shadow_sampler, xy);
  float current_sample = vertexIn.shadowPosition.z / vertexIn.shadowPosition.w - bias;
  
  if (current_sample < shadow_sample ) {
    color = float4(1, 0, 1, 1);
  } else {
    color = float4(shadow_sample, 0, shadow_sample, 1);
  }
  
  return half4(color);
}

fragment half4 color_shader(VertexOut vertexIn [[stage_in]],
                            constant float4 &color [[buffer(1)]]) {
  return half4(color);
}


vertex float4 vertex_zOnly(device Vertex *vertices [[buffer(0)]],
                           constant Constants &constants [[buffer(1)]],
                           uint vertexId [[vertex_id]]) {
  Vertex vertexIn = vertices[vertexId];
  float4 position = constants.modelViewProjectionMatrix * vertexIn.position;
  position = constants.shadowViewProjectionMatrix * vertexIn.position;
  return position;
}

