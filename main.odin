package main

import "core:fmt"
import sdl "vendor:sdl3"
import la "core:math/linalg"
import math "core:math"

Vec3:: [3]f64
Point:: [3]f64
Color :: [3]f64

ASPECT_RATIO :f64: 16.0/9.0
HEIGHT:: 720
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
    material_ground : Material = Lambert{Color{0.8, 0.8, 0.0}}
    material_center : Material = Lambert{Color{0.1, 0.2, 0.5}}
    material_left   : Material = Dielectric{1.5}
    material_bubble : Material = Dielectric{1.00 / 1.50}
    material_right  : Material = Metallic{Color{0.8, 0.6, 0.2},0.9}

    append(&objects,
        Sphere{Point{0.0, -100.5, -1.0},100.0,material_ground},
        Sphere{Point{0.0,  0.0,   -1.2},0.5  ,material_center},
        Sphere{Point{-1.0, 0.0,   -1.0},0.5  ,material_left},
        Sphere{Point{-1.0, 0.0,   -1.0},0.4  ,material_bubble},
        Sphere{Point{1.0,  0.0,   -1.0},0.5  ,material_right},
    )

    render(camera,objects)

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