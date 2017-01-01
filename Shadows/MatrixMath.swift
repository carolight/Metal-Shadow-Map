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
 * Mathematical functions are courtesy of Warren Moore and his
 * excellent book Metal By Example. Thank you.
 * http://metalbyexample.com
 *
 * Any mathematical errors are my own.
 *
 */

import simd

let π = Float(M_PI)

func radians(fromDegrees degrees: Float) -> Float {
  return (degrees / 180) * π
}

func degrees(fromRadians radians: Float) -> Float {
  return (radians / π) * 180
}

extension matrix_float4x4 {
  init(translationX x: Float, y: Float, z: Float) {
    columns = (
      float4( 1,  0,  0,  0),
      float4( 0,  1,  0,  0),
      float4( 0,  0,  1,  0),
      float4( x,  y,  z,  1)
    )
  }
  
  func translatedBy(x: Float, y: Float, z: Float) -> matrix_float4x4 {
    let translateMatrix = matrix_float4x4(translationX: x, y: y, z: z)
    return matrix_multiply(self, translateMatrix)
  }
  
  init(scaleX x: Float, y: Float, z: Float) {
    columns = (
      float4( x,  0,  0,  0),
      float4( 0,  y,  0,  0),
      float4( 0,  0,  z,  0),
      float4( 0,  0,  0,  1)
    )
  }
  
  func scaledBy(x: Float, y: Float, z: Float) -> matrix_float4x4 {
    let scaledMatrix = matrix_float4x4(scaleX: x, y: y, z: z)
    return matrix_multiply(self, scaledMatrix)
  }
  
  // angle should be in radians
  init(rotationAngle angle: Float, x: Float, y: Float, z: Float) {
    let c = cos(angle)
    let s = sin(angle)

    var column0 = float4(0)
    column0.x = x * x + (1 - x * x) * c
    column0.y = x * y * (1 - c) - z * s
    column0.z = x * z * (1 - c) + y * s
    column0.w = 0
    
    var column1 = float4(0)
    column1.x = x * y * (1 - c) + z * s
    column1.y = y * y + (1 - y * y) * c
    column1.z = y * z * (1 - c) - x * s
    column1.w = 0.0
    
    var column2 = float4(0)
    column2.x = x * z * (1 - c) - y * s
    column2.y = y * z * (1 - c) + x * s
    column2.z = z * z + (1 - z * z) * c
    column2.w = 0.0
    
    let column3 = float4(0, 0, 0, 1)
    
    columns = (
      column0, column1, column2, column3
    )
  }
  
  func rotatedBy(rotationAngle angle: Float,
                 x: Float, y: Float, z: Float) -> matrix_float4x4 {
    let rotationMatrix = matrix_float4x4(rotationAngle: angle,
                                         x: x, y: y, z: z)
    return matrix_multiply(self, rotationMatrix)
  }
  
  init(projectionFov fov: Float, aspect: Float, nearZ: Float, farZ: Float) {
    let y = 1 / tan(fov * 0.5)
    let x = y / aspect
    let z = farZ / (nearZ - farZ)
    columns = (
      float4( x,  0,  0,  0),
      float4( 0,  y,  0,  0),
      float4( 0,  0,  z, -1),
      float4( 0,  0,  z * nearZ,  0)
    )
  }
  
  func upperLeft3x3() -> matrix_float3x3 {
    return (matrix_float3x3(columns: (
      float3(columns.0.x, columns.0.y, columns.0.z),
      float3(columns.1.x, columns.1.y, columns.1.z),
      float3(columns.2.x, columns.2.y, columns.2.z)
    )))
  }
}

extension matrix_float4x4: CustomReflectable {
  
  public var customMirror: Mirror {
    let c00 = String(format: "%  .4f", columns.0.x)
    let c01 = String(format: "%  .4f", columns.0.y)
    let c02 = String(format: "%  .4f", columns.0.z)
    let c03 = String(format: "%  .4f", columns.0.w)
    
    let c10 = String(format: "%  .4f", columns.1.x)
    let c11 = String(format: "%  .4f", columns.1.y)
    let c12 = String(format: "%  .4f", columns.1.z)
    let c13 = String(format: "%  .4f", columns.1.w)
    
    let c20 = String(format: "%  .4f", columns.2.x)
    let c21 = String(format: "%  .4f", columns.2.y)
    let c22 = String(format: "%  .4f", columns.2.z)
    let c23 = String(format: "%  .4f", columns.2.w)
    
    let c30 = String(format: "%  .4f", columns.3.x)
    let c31 = String(format: "%  .4f", columns.3.y)
    let c32 = String(format: "%  .4f", columns.3.z)
    let c33 = String(format: "%  .4f", columns.3.w)
    
    
    let children = DictionaryLiteral<String, Any>(dictionaryLiteral:
      (" ", "\(c00) \(c01) \(c02) \(c03)"),
      (" ", "\(c10) \(c11) \(c12) \(c13)"),
      (" ", "\(c20) \(c21) \(c22) \(c23)"),
      (" ", "\(c30) \(c31) \(c32) \(c33)")
    )
    return Mirror(matrix_float4x4.self, children: children)
  }
}

extension float4: CustomReflectable {
  
  public var customMirror: Mirror {
    let sx = String(format: "%  .4f", x)
    let sy = String(format: "%  .4f", y)
    let sz = String(format: "%  .4f", z)
    let sw = String(format: "%  .4f", w)
    
    let children = DictionaryLiteral<String, Any>(dictionaryLiteral:
      (" ", "\(sx) \(sy) \(sz) \(sw)")
    )
    return Mirror(float4.self, children: children)
  }
}

