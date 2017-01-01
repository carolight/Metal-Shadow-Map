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

import MetalKit

class Renderer: NSObject {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  
  struct Constants {
    var modelViewProjectionMatrix = matrix_identity_float4x4
    var shadowViewProjectionMatrix = matrix_identity_float4x4
  }
  
  var planeConstants = Constants()
  var cubeConstants = Constants()
  var lightConstants = Constants()
  
  var pipelineState: MTLRenderPipelineState?
  var planeVertexBuffer: MTLBuffer?
  var planeIndexBuffer: MTLBuffer?
  var cubeVertexBuffer: MTLBuffer?
  var cubeIndexBuffer: MTLBuffer?
  var lightVertexBuffer: MTLBuffer?
  
  var projectionMatrix = matrix_identity_float4x4
  
  var depthStencilState: MTLDepthStencilState?
  
  var lightMatrix = matrix_identity_float4x4
  var cameraMatrix = matrix_identity_float4x4
  
  // for shadows
  var shadowPipelineState: MTLRenderPipelineState?
  var shadowRenderPassDescriptor: MTLRenderPassDescriptor?
  var shadowTexture: MTLTexture?
  var shadowDepthStencilState: MTLDepthStencilState?
  
  // for simple color shading
  var colorPipelineState: MTLRenderPipelineState?
  
  init(device: MTLDevice) {
    self.device = device
    commandQueue = device.makeCommandQueue()
    super.init()
    
    buildPipelineState()
    buildModel()
    buildSceneConstants()
  }
  
  private func buildModel() {
    planeVertexBuffer = device.makeBuffer(bytes: planeVertices,
                                          length: planeVertices.count * MemoryLayout<Vertex>.stride,
                                          options: [])
    planeIndexBuffer = device.makeBuffer(bytes: planeIndices,
                                         length: planeIndices.count * MemoryLayout<UInt16>.size,
                                         options: [])
    cubeVertexBuffer = device.makeBuffer(bytes: cubeVertices,
                                         length: cubeVertices.count * MemoryLayout<Vertex>.stride,
                                         options: [])
    cubeIndexBuffer = device.makeBuffer(bytes: cubeIndices,
                                        length: cubeIndices.count * MemoryLayout<UInt16>.size,
                                        options: [])
    lightVertexBuffer = device.makeBuffer(bytes: cubeVertices,
                                              length: cubeVertices.count * MemoryLayout<Vertex>.stride,
                                              options: [])
  }
  
  func buildSceneConstants() {
    lightMatrix = matrix_float4x4(translationX: 0, y: 0, z: -2)
    lightMatrix = lightMatrix.rotatedBy(rotationAngle: radians(fromDegrees: -70), x: 1, y: 0, z: 0)
    cameraMatrix = matrix_float4x4(translationX: 0, y: 0, z: -4)
  }
  
  private func buildPipelineState() {
    let library = device.newDefaultLibrary()
    let vertexFunction = library?.makeFunction(name: "vertex_shader")
    let fragmentFunction = library?.makeFunction(name: "fragment_shader")
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    
    do {
      pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error as NSError {
      fatalError("error: \(error.localizedDescription)")
    }
    
    let depthStencilDescriptor = MTLDepthStencilDescriptor()
    depthStencilDescriptor.depthCompareFunction = .less
    depthStencilDescriptor.isDepthWriteEnabled = true
    depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    
    // build Shadow requirements
    
    // receiving shadow texture
    let shadowTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                           width: 1024, height: 1024,
                                                                           mipmapped: false)
    shadowTexture = device.makeTexture(descriptor: shadowTextureDescriptor)
    guard let shadowTexture = shadowTexture else { return }
    shadowTexture.label = "shadow map"
    
    shadowRenderPassDescriptor = MTLRenderPassDescriptor()
    let shadowAttachment = shadowRenderPassDescriptor!.depthAttachment
    shadowAttachment?.texture = shadowTexture
    shadowAttachment?.loadAction = .clear
    shadowAttachment?.storeAction = .store
    shadowAttachment?.clearDepth = 1.0
    
    // set up pipeline with correct vertex function / no fragment function needed
    let shadowVertexFunction = library?.makeFunction(name: "vertex_zOnly")
    pipelineDescriptor.vertexFunction = shadowVertexFunction
    pipelineDescriptor.fragmentFunction = nil
    pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
    pipelineDescriptor.depthAttachmentPixelFormat = shadowTexture.pixelFormat
    
    do {
      shadowPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error as NSError {
      fatalError("error: \(error.localizedDescription)")
    }
    
    depthStencilDescriptor.depthCompareFunction = .lessEqual
    depthStencilDescriptor.isDepthWriteEnabled = true
    shadowDepthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    
    // create simple color shader pipeline
    let colorFunction = library?.makeFunction(name: "color_shader")
    let colorPipelineDescriptor = MTLRenderPipelineDescriptor()
    colorPipelineDescriptor.vertexFunction = vertexFunction
    colorPipelineDescriptor.fragmentFunction = colorFunction
    colorPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    
    do {
      colorPipelineState = try device.makeRenderPipelineState(descriptor: colorPipelineDescriptor)
    } catch let error as NSError {
      fatalError("error: \(error.localizedDescription)")
    }

  }
  
  
  func update(matrix: matrix_float4x4, deltaTime: Float) {
    
    var lightModelMatrix = matrix_float4x4(translationX: 0, y: 2, z: 0)
    
    lightModelMatrix = lightModelMatrix.scaledBy(x: 0.1, y: 0.1, z: 0.2)
    
    var planeModelMatrix = matrix_float4x4(translationX: 0, y: -2, z: 0)
    planeModelMatrix = planeModelMatrix.rotatedBy(rotationAngle: radians(fromDegrees: 90), x: 1, y: 0, z: 0)
    
    var cubeModelMatrix = matrix_float4x4(rotationAngle: radians(fromDegrees: 30), x: 0, y: 1, z: 0)
    cubeModelMatrix = cubeModelMatrix.scaledBy(x: 0.5, y: 0.5, z: 0.5)
    
    var modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(matrix, planeModelMatrix))
    planeConstants.modelViewProjectionMatrix = modelViewProjectionMatrix
    
    modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(matrix, cubeModelMatrix))
    cubeConstants.modelViewProjectionMatrix = modelViewProjectionMatrix
    
    modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(matrix, lightModelMatrix))
    lightConstants.modelViewProjectionMatrix = modelViewProjectionMatrix
    
  }
}

extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    let aspect: Float = Float(size.width / size.height)
    let fov: Float = radians(fromDegrees: 75)
    let near: Float = 0.1
    let far: Float = 100
    projectionMatrix = matrix_float4x4(projectionFov: fov, aspect: aspect, nearZ: near, farZ: far)
  }
  
  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let descriptor = view.currentRenderPassDescriptor,
      let pipelineState = pipelineState,
      let shadowPipelineState = shadowPipelineState,
      let colorPipelineState = colorPipelineState,
      let shadowRenderPassDescriptor = shadowRenderPassDescriptor,
      
      let planeIndexBuffer = planeIndexBuffer,
      let cubeIndexBuffer = cubeIndexBuffer
      else { return }
    
    let deltaTime = 1/Float(view.preferredFramesPerSecond)
    
    let commandBuffer = commandQueue.makeCommandBuffer()
    var encoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor)
    
    // shadow pass
    
    update(matrix: lightMatrix, deltaTime: deltaTime)
    
    planeConstants.shadowViewProjectionMatrix =  planeConstants.modelViewProjectionMatrix
    cubeConstants.shadowViewProjectionMatrix =  cubeConstants.modelViewProjectionMatrix
    
    
    encoder.pushDebugGroup("shadow pass")
    encoder.label = "shadow"
    
    encoder.setCullMode(.back)
    encoder.setFrontFacing(.counterClockwise)
    encoder.setVertexBytes(&planeConstants,
                                  length: MemoryLayout<Constants>.stride,
                                  at: 1)
    encoder.setRenderPipelineState(shadowPipelineState)
    encoder.setDepthStencilState(depthStencilState)
    
    // draw plane
    encoder.setVertexBuffer(planeVertexBuffer, offset: 0, at: 0)
    encoder.drawIndexedPrimitives(type: .triangle,
                                         indexCount: planeIndices.count,
                                         indexType: .uint16,
                                         indexBuffer: planeIndexBuffer,
                                         indexBufferOffset: 0)
    
    // draw cube
    encoder.setVertexBytes(&cubeConstants,
                                  length: MemoryLayout<Constants>.size,
                                  at: 1)
    encoder.setVertexBuffer(cubeVertexBuffer, offset: 0, at: 0)
    encoder.drawIndexedPrimitives(type: .triangle,
                                         indexCount: cubeIndices.count,
                                         indexType: .uint16,
                                         indexBuffer: cubeIndexBuffer,
                                         indexBufferOffset: 0)
    encoder.popDebugGroup()
    encoder.endEncoding()
    
    // main pass
    update(matrix: cameraMatrix, deltaTime: deltaTime)
    
    encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    encoder.pushDebugGroup("main pass")
    encoder.label = "main"
    
    encoder.setCullMode(.back)
    encoder.setFrontFacing(.counterClockwise)
    
    // draw plane
    encoder.setVertexBytes(&planeConstants,
                           length: MemoryLayout<Constants>.stride,
                           at: 1)
    encoder.setRenderPipelineState(pipelineState)
    encoder.setDepthStencilState(depthStencilState)
    
    encoder.setFragmentTexture(shadowTexture, at: 0)
    encoder.setVertexBuffer(planeVertexBuffer, offset: 0, at: 0)
    encoder.drawIndexedPrimitives(type: .triangle,
                                  indexCount: planeIndices.count,
                                  indexType: .uint16,
                                  indexBuffer: planeIndexBuffer,
                                  indexBufferOffset: 0)
    
    // draw cube
    encoder.setVertexBytes(&cubeConstants,
                           length: MemoryLayout<Constants>.stride,
                           at: 1)
    encoder.setVertexBuffer(cubeVertexBuffer, offset: 0, at: 0)
    encoder.drawIndexedPrimitives(type: .triangle,
                                  indexCount: cubeIndices.count,
                                  indexType: .uint16,
                                  indexBuffer: cubeIndexBuffer,
                                  indexBufferOffset: 0)
    
    
    encoder.popDebugGroup()
    
    encoder.pushDebugGroup("light")
    
    encoder.setRenderPipelineState(colorPipelineState)
    encoder.setDepthStencilState(depthStencilState)

    // draw "light"
    encoder.setVertexBytes(&lightConstants,
                           length: MemoryLayout<Constants>.stride,
                           at: 1)
    encoder.setVertexBuffer(lightVertexBuffer, offset: 0, at: 0)
    var color = float4(1, 1, 0, 1)
    encoder.setFragmentBytes(&color, length: MemoryLayout<float4>.stride, at: 1)
    
    encoder.drawIndexedPrimitives(type: .triangle,
                                  indexCount: cubeIndices.count,
                                  indexType: .uint16,
                                  indexBuffer: cubeIndexBuffer,
                                  indexBufferOffset: 0)

    encoder.popDebugGroup()
    encoder.endEncoding()

    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

