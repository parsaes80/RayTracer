package main

import la "core:math/linalg"
import math "core:math"
import rand "core:math/rand"
import runtime "base:runtime"
import "core:thread"

ray_color::proc(r:Ray,depth:int,objects:[dynamic]Hittable)->Color{
    if depth <= 0 do return Color{0,0,0}
    rec:HitRecord
    if hit_all(r, Interval{0.01,math.INF_F64}, &rec,objects) {
        scattered:Ray
        attenuation:Color
        if scatter(r,&rec,&attenuation,&scattered,rec.mat){
            return attenuation*ray_color(scattered,depth-1,objects)
        }
        else do return Color{0,0,0}
    }
    unit_direction := la.normalize(r.dir)
    a := 0.5*(unit_direction.y + 1.0)
    return (1.0-a)*Color{1.0, 1.0, 1.0} + a*Color{0.5, 0.7, 1.0}
}

write_color ::proc (pixel_color:Color) -> u32{
    intensity := Interval{0.0,0.99999}
    r := linear_to_gamma(pixel_color.r)
    g := linear_to_gamma(pixel_color.g)
    b := linear_to_gamma(pixel_color.b)
    ir := u32(255.999 * interval_clamp(intensity,r))
    ig := u32(255.999 * interval_clamp(intensity,g))
    ib := u32(255.999 * interval_clamp(intensity,b))
    return (ir << 24) | (ig << 16) | (ib << 8) | 0xFF
}

render::proc(start:i64,end:i64,camera:Camera,objects:[dynamic]Hittable){

    for j :i64= 0; j < HEIGHT; j+=1 {
        for i :i64= start; i < end; i+=1 {
            pixel_color := Color{0,0,0}
            for sample:i64=0;sample<camera.samples_per_pixel;sample+= 1{
                r := get_ray(i,j,camera)
                pixel_color += ray_color(r,camera.max_depth,objects)
            }
            Framebuffer[j][i] = write_color(pixel_color/f64(camera.samples_per_pixel))
        }
    }
}

RenderJob :: struct {
    start: i64,
    end: i64,
    camera: Camera,
    objects: [dynamic]Hittable,
    seed: u64,
}

render_worker :: proc(data: rawptr) {
    job := (^RenderJob)(data)

    rng_state: rand.PCG_Random_State
    context.random_generator = rand.pcg_random_generator(&rng_state)
    rand.reset_u64(job^.seed)

    render(job^.start, job^.end, job^.camera, job^.objects)
}

render_parallel::proc(camera:Camera,world:World){

    thread_count := 16

    rows_per_thread := int(WIDTH) / thread_count
    remainder := int(WIDTH) % thread_count
    threads: [dynamic]^thread.Thread
    jobs: [16]RenderJob

    y := 0
    for i := 0; i < thread_count; i += 1 {
        extra := 0
        if i < remainder do extra = 1
        start := y
        end := y + rows_per_thread + extra
        y = end

        jobs[i] = RenderJob{
            start = i64(start),
            end = i64(end),
            camera = camera,
            objects = world.objects,
            seed = u64(runtime.read_cycle_counter()) + u64(i) * 7919,
        }
        t := thread.create_and_start_with_data(&jobs[i], render_worker)
        append(&threads, t)
    }

    for t in threads {
        thread.destroy(t)
    }
}