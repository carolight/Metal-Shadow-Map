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

class ViewController: UIViewController {

  var metalView: MTKView {
    return view as! MTKView
  }
  
  var renderer: Renderer?

  override func viewDidLoad() {
    super.viewDidLoad()

    metalView.device = MTLCreateSystemDefaultDevice()
    guard let device = metalView.device else {
      fatalError()
    }
    metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 1, alpha: 1)
    
    renderer = Renderer(device: device)
    metalView.delegate = renderer
  }
}

