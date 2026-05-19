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

//func :: proc() {}
//f: proc() = func
//f()

Sphere:: struct{
    center:Point,
    radius:f64
}

Ray :: struct{
    orig : Point,
    dir : Vec3
}

HitRecord :: struct{
    p:Point,
    normal:Vec3,
    t:f64,
    front_face: bool
}

Interval::struct{
    min:f64,
    max:f64
}

set_face_normal:: proc(r:Ray,outward_normal:Vec3)->(bool,Vec3){
    front_face := la.dot(r.dir,outward_normal) < 0
    normal := front_face ? outward_normal : -outward_normal
    return front_face,normal
}

ray_at::proc(ray:Ray,t:f64)-> Vec3{
    return ray.orig+t*ray.dir
}

hit_all:: proc(r:Ray, ray_tmin:f64,ray_tmax:f64,rec:^HitRecord,objects:[dynamic]Sphere)->bool{
    temp_rec : HitRecord
    hit_anything:bool = false;
    closest_so_far:f64 = ray_tmax;

    for obj  in objects {
        if hit_sphere(obj,r, ray_tmin, closest_so_far, &temp_rec) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec^ = temp_rec;
        }
    }

    return hit_anything;
}


hit_sphere::proc(sphere:Sphere,r:Ray,ray_tmin:f64,ray_tmax:f64,rec:^HitRecord)->bool{
    oc := sphere.center - r.orig
    a := la.dot(r.dir,r.dir)
    h := la.dot(r.dir,oc) 
    c := la.dot(oc,oc) -sphere.radius*sphere.radius
    discriminant := h*h - a*c
    if discriminant < 0 do return false
    sqrtd := math.sqrt(discriminant)
    root := (h - sqrtd) / a
    if root <= ray_tmin || ray_tmax <= root{
        root = (h + sqrtd) / a;
        if root <= ray_tmin || ray_tmax <= root do return false
    }
    rec.t= root
    rec.p = ray_at(r,rec.t)
    outward_normal : Vec3 = (rec.p - sphere.center) / sphere.radius;
    rec.front_face, rec.normal = set_face_normal(r,outward_normal)

    return true
}

ray_color::proc(r:Ray,objects:[dynamic]Sphere)->Color{
    rec:HitRecord
    if hit_all(r, 0, 9999999999, &rec,objects) {
        return 0.5 * (rec.normal + Color{1,1,1})
    }
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

    window := sdl.CreateWindow("sup",WIDTH,HEIGHT,{})
    defer sdl.DestroyWindow(window)

    renderer := sdl.CreateRenderer(window,nil); assert(renderer != nil,"renderer failed")
    defer sdl.DestroyRenderer(renderer)

    texture := sdl.CreateTexture(renderer,.RGBA8888,.STREAMING,WIDTH,HEIGHT); assert(texture != nil,"texture failed")
    defer sdl.DestroyTexture(texture)

    viewport_height := 2.0
    viewport_width := viewport_height * ASPECT_RATIO
    focal_length := 1.0

    camera_center := Point{0,0,0}

    viewport_u := Point{viewport_width, 0, 0}
    viewport_v := Point{0, -viewport_height, 0}
    pixel_delta_u := viewport_u / WIDTH
    pixel_delta_v := viewport_v / HEIGHT

    // Calculate the location of the upper left pixel.
    viewport_upper_left := camera_center - Point{0, 0, focal_length} - viewport_u/2 - viewport_v/2;
    pixel00_loc := viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);

    objects:[dynamic]Sphere
    append(&objects,Sphere{Point{0,0,-1},0.5},Sphere{Point{0,-100.5,-1},100})

    for j := 0; j < HEIGHT; j+=1 {
        for i := 0; i < WIDTH; i+=1 {
            pixel_center := pixel00_loc + (f64(i) * pixel_delta_u) + (f64(j) * pixel_delta_v);
            ray_direction := pixel_center - camera_center;
            r:= Ray{camera_center, ray_direction};

            pixel_color := ray_color(r,objects);
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