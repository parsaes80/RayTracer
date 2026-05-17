package raytacer

import "core:fmt"
import sdl "vendor:sdl3"
import la "core:math/linalg"

Vec3:: [3]f64

Color :: [3]f64

ASPECT_RATIO :f64: 16.0/9.0
HEIGHT:: 720
WIDTH:: HEIGHT* 16/9

Framebuffer : [HEIGHT][WIDTH] u32 

Ray :: struct{
    orig : Vec3,
    dir : Vec3 
}

at::proc(ray:Ray,t:f64)-> Vec3{
    return ray.orig+t*ray.dir
}
hit_sphere::proc(center:Vec3,radius:f64,r:Ray)->bool{
    oc := center - r.orig
    a := la.dot(r.dir,r.dir)
    b := -2.0 * la.dot(r.dir,oc)
    c := la.dot(oc,oc) -radius*radius
    discriminate := b*b - 4*a*c
    return discriminate >= 0
}
ray_color::proc(r:Ray)->Color{
    if hit_sphere(Vec3{0,0,-1},0.5,r) do return Color{1,0,0}
    unit_direction := la.normalize(r.dir)
    a := 0.5*(unit_direction.y + 1.0)
    return (1.0-a)*Color{1.0, 1.0, 1.0} + a*Color{0.5, 0.7, 1.0}
}

write_color ::proc (pixel_color:Color) -> u32{
    ir := u32(255.999 * pixel_color.r)
    ig := u32(255.999 * pixel_color.g)
    ib := u32(255.999 * pixel_color.b)
    return (ir << 24) | (ig << 16) | (ib << 8) | 0xFF
}

main :: proc(){
    running := true

    res := sdl.Init({.VIDEO}); assert(res,"init failed")

    window := sdl.CreateWindow("sup",WIDTH,HEIGHT,{.RESIZABLE})
    defer sdl.DestroyWindow(window)

    renderer := sdl.CreateRenderer(window,nil); assert(renderer != nil,"renderer failed")
    defer sdl.DestroyRenderer(renderer)

    texture := sdl.CreateTexture(renderer,.RGBA8888,.STREAMING,WIDTH,HEIGHT); assert(texture != nil,"texture failed")
    defer sdl.DestroyTexture(texture)

    viewport_height := 2.0
    viewport_width := viewport_height * ASPECT_RATIO
    focal_length := 1.0

    camera_center := Vec3{0,0,0}

    viewport_u := Vec3{viewport_width, 0, 0}
    viewport_v := Vec3{0, -viewport_height, 0}
    pixel_delta_u := viewport_u / WIDTH
    pixel_delta_v := viewport_v / HEIGHT

    // Calculate the location of the upper left pixel.
    viewport_upper_left := camera_center - Vec3{0, 0, focal_length} - viewport_u/2 - viewport_v/2;
    pixel00_loc := viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);

    for j := 0; j < HEIGHT; j+=1 {
        for i := 0; i < WIDTH; i+=1 {
            pixel_center := pixel00_loc + (f64(i) * pixel_delta_u) + (f64(j) * pixel_delta_v);
            ray_direction := pixel_center - camera_center;
            r:= Ray{camera_center, ray_direction};

            pixel_color := ray_color(r);
            Framebuffer[j][i] = write_color(pixel_color)
        }
    }

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