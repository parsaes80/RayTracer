package raytacer

import "core:fmt"
import sdl "vendor:sdl3"
import la "core:math/linalg"
import math "core:math"

Vec3:: [3]f64
Point:: [3]f64
Color :: [3]f64

ASPECT_RATIO :f64: 16.0/9.0
HEIGHT:: 1080
WIDTH:: HEIGHT* 16/9

Framebuffer : [HEIGHT][WIDTH] u32 

main :: proc(){
    running := true
    res := sdl.Init({.VIDEO}); assert(res,"init failed")

    window := sdl.CreateWindow("sup",WIDTH,HEIGHT,{})
    defer sdl.DestroyWindow(window)

    renderer := sdl.CreateRenderer(window,nil); assert(renderer != nil,"renderer failed")
    defer sdl.DestroyRenderer(renderer)

    texture := sdl.CreateTexture(renderer,.RGBA8888,.STREAMING,WIDTH,HEIGHT); assert(texture != nil,"texture failed")
    defer sdl.DestroyTexture(texture)

    camera := create_camera()

    objects:[dynamic]Sphere
    append(&objects,Sphere{Point{0,0,-1},0.5},Sphere{Point{0,-100.5,-1},100})

    render(&camera,objects)

    event: sdl.Event
    for running {
        for sdl.PollEvent(&event) {
            if event.type == sdl.EventType.QUIT {
                running = false
            }
        }
        
        sdl.UpdateTexture(texture,nil,&Framebuffer,WIDTH*size_of(u32))
        sdl.RenderClear(renderer)
        sdl.RenderTexture(renderer,texture,nil,nil)
        sdl.RenderPresent(renderer)
        sdl.Delay(16)
    }

    sdl.Quit()
}



//func :: proc() {}
//f: proc() = func
//f()