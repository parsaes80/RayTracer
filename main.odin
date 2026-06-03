package main

import "core:fmt"
import sdl "vendor:sdl3"
import la "core:math/linalg"
import math "core:math"
import rand "core:math/rand"
import "core:thread"

Vec3:: [3]f64
Point:: [3]f64
Color :: [3]f64

ASPECT_RATIO :f64: 16.0/9.0
HEIGHT:: 720
SAMPLES_PER_PIXEL::100
MAX_DEPTH :: 10
VFOV:: 30.0

WIDTH:: HEIGHT* 16/9

Framebuffer : [HEIGHT][WIDTH] u32 

global:GlobalData

GlobalData::struct{
    camera:Camera,
    world:World
}

main :: proc(){
    running := true
    res := sdl.Init({.VIDEO}); assert(res,"init failed")

    window := sdl.CreateWindow("sup",WIDTH,HEIGHT,{})
    defer sdl.DestroyWindow(window)

    renderer := sdl.CreateRenderer(window,nil); assert(renderer != nil,"renderer failed")
    defer sdl.DestroyRenderer(renderer)

    texture := sdl.CreateTexture(renderer,.RGBA8888,.STREAMING,WIDTH,HEIGHT); assert(texture != nil,"texture failed")
    defer sdl.DestroyTexture(texture)

    global.camera = create_camera()

    ground_material : Material = Lambert{Color{0.5, 0.5, 0.5}}
    append(&global.world.objects, make_sphere(Point{0.0, -1000.0, 0.0}, 1000.0, ground_material))

    for a := -11; a < 11; a += 1 {
        for b := -11; b < 11; b += 1 {
            choose_mat := rand.float64()
            center := Point{f64(a) + 0.9*rand.float64(), 0.2, f64(b) + 0.9*rand.float64()}

            if la.length(center - Point{4.0, 0.2, 0.0}) > 0.9 {
                if choose_mat < 0.8 {
                    albedo := random_vector(0.0, 1.0) * random_vector(0.0, 1.0)
                    center2 := center + Vec3{0,rand.float64_range(0,0.5),0}
                    append(&global.world.objects, make_sphere(center,center2, 0.2, Lambert{albedo}))
                } else if choose_mat < 0.95 {
                    albedo := random_vector(0.5, 1.0)
                    fuzz := rand.float64_range(0.0, 0.5)
                    append(&global.world.objects, make_sphere(center, 0.2, Metallic{albedo, fuzz}))
                } else {
                    append(&global.world.objects, make_sphere(center, 0.2, Dielectric{1.5}))
                }
            }
        }
    }

    material1 : Material = Dielectric{1.5}
    material2 : Material = Lambert{Color{0.4, 0.2, 0.1}}
    material3 : Material = Metallic{Color{0.7, 0.6, 0.5}, 0.0}
    
    append(&global.world.objects,
        make_sphere(Point{0.0, 1.0, 0.0}, 1.0, material1),
        make_sphere(Point{-4.0, 1.0, 0.0}, 1.0, material2),
        make_sphere(Point{4.0, 1.0, 0.0}, 1.0, material3),
    )
    
    
    raw_objects := global.world.objects
    bvh_root := make_BVH_Node(raw_objects)
    bvh: [dynamic]Hittable
    append(&bvh, bvh_root)
    global.world.objects = bvh
    
    t := thread.create_and_start(render_parallel)

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

