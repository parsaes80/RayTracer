package main

import "vendor:zlib"
import "core:fmt"
import sdl "vendor:sdl3"
import la "core:math/linalg"
import math "core:math"
import rand "core:math/rand"
import "core:sync"
import "core:thread"
import runtime "base:runtime"

Interval::struct{
    min:f64,
    max:f64
}

interval_size::proc(interval:Interval,x:f64)->f64{
    return interval.max - interval.min
}

interval_contains::proc(interval:Interval,x:f64)->bool{
    return interval.min <= x && x <= interval.max
}

interval_surrounds::proc(interval:Interval,x:f64)->bool{
    return interval.min < x && x < interval.max
}

interval_clamp::proc(interval:Interval,x:f64)->f64{
    if x>interval.max do return interval.max
    else if x<interval.min do return interval.min
    return x
}
expand::proc(interval:Interval,delta:f64)->Interval {
    padding := delta/2
    return Interval{interval.min - padding, interval.max + padding}
}

empty:Interval: Interval{math.INF_F64,math.NEG_INF_F64}
universe:Interval: Interval{math.NEG_INF_F64,math.INF_F64}

aabb::struct{
    x:Interval,
    y:Interval,
    z:Interval
}

make_aabb::proc(a:Point,b:Point)->aabb{
    box:aabb
    box.x = (a[0] <= b[0]) ? Interval{a[0], b[0]} : Interval{b[0], a[0]}
    box.y = (a[1] <= b[1]) ? Interval{a[1], b[1]} : Interval{b[1], a[1]}
    box.z = (a[2] <= b[2]) ? Interval{a[2], b[2]} : Interval{b[2], a[2]}
    return box
}

axis_interval::proc(box:aabb,n:int)->Interval{
    if n==1 do return box.y
    if n==2 do return box.z
    return box.x
}

hit_aabb::proc(box:aabb,r:Ray,ray_t:Interval)->bool{
    ray_orig := r.orig
    ray_dir  := r.dir
    interval := ray_t

    for axis := 0; axis < 3; axis+=1 {
        ax := axis_interval(box,axis)
        adinv := 1.0 / ray_dir[axis];

        t0 := (ax.min - ray_orig[axis]) * adinv;
        t1 := (ax.max - ray_orig[axis]) * adinv;

        if t0 < t1 {
            if t0 > interval.min do interval.min = t0;
            if t1 < interval.max do interval.max = t1;
        } else {
            if t1 > interval.min do interval.min = t1;
            if t0 < interval.max do interval.max = t0;
        }

        if interval.max <= interval.min do return false;
    }
    return true;

}

Sphere:: struct{
    center:Ray,
    radius:f64,
    mat:Material,
}
make_sphere_s::proc(static_center:Point,radius:f64,mat:Material)->Sphere{
    return Sphere{Ray{static_center,Vec3{0,0,0},0},radius,mat}
}
make_sphere_d::proc(center1:Point,center2:Point,radius:f64,mat:Material)->Sphere{
    return Sphere{Ray{center1,center2-center1,0},radius,mat}
}
make_sphere::proc{make_sphere_s,make_sphere_d}
Ray :: struct{
    orig : Point,
    dir : Vec3,
    tm:f64
}

HitRecord :: struct{
    p:Point,
    normal:Vec3,
    t:f64,
    front_face: bool,
    mat:Material
}

MaterialType::enum{Lambert,Metal,Dielectric}

Lambert :: struct {
  albedo: Color
}

Metallic :: struct {
  color: Color,
  fuzz: f64
}

Dielectric :: struct {
    refraction_index: f64
}

Material :: union {
    Lambert,
    Metallic,
    Dielectric
}

Camera::struct{
    aspect_ratio:f64,
    image_height:i64, 
    image_width:i64,
    look_from:Point,
    look_at:Point,
    vup:Vec3,        
    vfov:f64,
    defocus_angle:f64,
    focus_dist:f64,
    defocus_disk_u:Vec3,
    defocus_disk_v:Vec3,
    pixel_delta_u:Vec3,   // Offset to pixel to the right
    pixel_delta_v:Vec3,   // Offset to pixel below
    pixel00_loc:Point,   // Location of pixel 0, 0
    samples_per_pixel:i64,
    max_depth:int
}

create_camera::proc()->Camera{
    //Given values
    samples_per_pixel : i64 = SAMPLES_PER_PIXEL
    max_depth := MAX_DEPTH
    vfov := VFOV

    defocus_angle := 0.6;
    focus_dist    := 10.0;

    look_from := Point{13,2,3}
    look_at := Point{0,0,0}
    vup := Vec3{0,1,0}

    center := look_from

    theta := la.RAD_PER_DEG * vfov
    h:= math.tan(theta/2)

    viewport_height := 2 * h * focus_dist
    viewport_width := viewport_height * ASPECT_RATIO

    w := la.normalize(look_from - look_at);
    u := la.normalize(la.cross(vup, w));
    v := la.cross(w, u);

    viewport_u := viewport_width * u
    viewport_v := viewport_height * -v

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    pixel_delta_u := viewport_u / WIDTH
    pixel_delta_v := viewport_v / HEIGHT

    // Calculate the location of the upper left pixel.
    viewport_upper_left := center - (focus_dist * w) - viewport_u/2 - viewport_v/2
    pixel00_loc := viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v)

    defocus_radius := focus_dist * math.tan(la.RAD_PER_DEG*defocus_angle / 2)
    defocus_disk_u := u * defocus_radius
    defocus_disk_v := v * defocus_radius

    return Camera{
        ASPECT_RATIO,
        HEIGHT,WIDTH,
        look_from,
        look_at,
        vup,
        vfov,
        defocus_angle,
        focus_dist,
        defocus_disk_u,
        defocus_disk_v,
        pixel_delta_u,
        pixel_delta_v,
        pixel00_loc,
        samples_per_pixel,
        max_depth}
}

random_vector1::proc()->Vec3{
    return Vec3{rand.float64(),rand.float64(),rand.float64()}
}
random_vector2::proc(min:f64,max:f64)->Vec3{
    return Vec3{rand.float64_range(min,max),rand.float64_range(min,max),rand.float64_range(min,max)}
}

random_vector::proc{random_vector1,random_vector2}

random_unit_vector::proc()->Vec3{
    for{
        p:= random_vector(-1,1)
        lensq := la.length2(p)
        if 1e-160 < lensq && lensq <= 1 do return p/math.sqrt(lensq)
    }
}

random_on_hemisphere::proc(normal:Vec3)->Vec3{
    rand_vec := random_unit_vector()
    if la.dot(rand_vec,normal) > 0.0 do return rand_vec
    else do return -rand_vec
}
random_in_unit_disk::proc()->Vec3{
    for{
        p := Vec3{rand.float64_range(-1,1), rand.float64_range(-1,1), 0}
        if la.length(p) < 1 do return p;
    }
}
linear_to_gamma::proc(linear_component:f64)->f64{
    if linear_component > 0 do return math.sqrt(linear_component)
    return 0
}

set_face_normal:: proc(r:Ray,outward_normal:Vec3)->(bool,Vec3){
    front_face := la.dot(r.dir,outward_normal) < 0
    normal := front_face ? outward_normal : -outward_normal
    return front_face,normal
}

ray_at::proc(ray:Ray,t:f64)-> Vec3{
    return ray.orig+t*ray.dir
}

reflect::proc(v:Vec3, n:Vec3)->Vec3 {
    return v - 2*la.dot(v,n)*n;
}

refract::proc(uv:Vec3,n:Vec3,nue_ratio:f64)->Vec3{
    cos_theta := math.min(la.dot(-uv,n),1.0)
    rout_perp := nue_ratio * (uv + cos_theta*n)
    rout_par  := -math.sqrt(math.abs(1.0 - la.length2(rout_perp))) * n
    return rout_par+rout_perp
}

scatter::proc(r:Ray, rec:^HitRecord,attenuation:^Color,scattered:^Ray,mat:Material)->bool{
    switch m in mat {
    case Lambert:
        scatter_direction := rec.normal + random_unit_vector()
        if la.length2(scatter_direction) <= 1e-24 do scatter_direction=rec.normal
        scattered^ = Ray{rec.p,scatter_direction,r.tm}
        attenuation^ = m.albedo
        return true
    case Metallic:
        reflected := reflect(la.normalize(r.dir), rec.normal)
        reflected = la.normalize(reflected) + (m.fuzz * random_unit_vector())
        scattered^ = Ray{rec.p, reflected,r.tm}
        attenuation^ = m.color
        return la.dot(scattered.dir, rec.normal) > 0
    case Dielectric:
        attenuation^ = Color{1.0, 1.0, 1.0}
        ri := rec.front_face ? (1.0/m.refraction_index) : m.refraction_index
        unit_direction := la.normalize(r.dir)
        cos_theta := math.min(la.dot(-unit_direction, rec.normal), 1.0);
        sin_theta := math.sqrt(1.0 - cos_theta*cos_theta);

        cannot_refract := ri * sin_theta > 1.0;
        direction:Vec3

        r0 := (1 - ri) / (1 + ri)
        r0 = r0*r0
        reflectance := r0 + (1-r0)* math.pow_f64((1 - cos_theta),5)

        if cannot_refract || reflectance>rand.float64() do direction = reflect(unit_direction, rec.normal);
        else do direction = refract(unit_direction, rec.normal, ri);

        scattered^ = Ray{rec.p, direction,r.tm}
        return true
    }
    return false
}

hit_all:: proc(r:Ray, ray_t:Interval,rec:^HitRecord,objects:[dynamic]Sphere)->bool{
    temp_rec : HitRecord
    hit_anything:bool = false;
    closest_so_far:f64 = ray_t.max;

    for obj  in objects {
        if hit_sphere(obj,r, Interval{ray_t.min,closest_so_far}, &temp_rec) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec^ = temp_rec;
        }
    }
    return hit_anything;
}

hit_sphere::proc(sphere:Sphere,r:Ray,ray_t:Interval,rec:^HitRecord)->bool{
    current_center := ray_at(sphere.center,r.tm)
    oc := current_center- r.orig
    a := la.length2(r.dir)
    h := la.dot(r.dir,oc) 
    c := la.length2(oc) -sphere.radius*sphere.radius
    discriminant := h*h - a*c
    if discriminant < 0 do return false
    sqrtd := math.sqrt(discriminant)
    root := (h - sqrtd) / a
    if !interval_surrounds(ray_t,root){
        root = (h + sqrtd) / a;
        if !interval_surrounds(ray_t,root) do return false
    }
    rec.t= root
    rec.p = ray_at(r,rec.t)
    outward_normal : Vec3 = (rec.p - current_center) / sphere.radius;
    rec.front_face, rec.normal = set_face_normal(r,outward_normal)
    rec.mat = sphere.mat
    return true
}

ray_color::proc(r:Ray,depth:int,objects:[dynamic]Sphere)->Color{
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

get_ray::proc(i:i64,j:i64,camera:Camera)->Ray{
    offset:= Vec3{rand.float64()-0.5,rand.float64()-0.5,0} 

    pixel_sample := camera.pixel00_loc +
    ((f64(i)+offset.x)*camera.pixel_delta_u) +
    (((f64(j)+offset.y)*camera.pixel_delta_v))

    p := random_in_unit_disk()
    defocus_disk_sample:= camera.look_from + (p[0] * camera.defocus_disk_u) + (p[1] * camera.defocus_disk_v);
    ray_origin := (camera.defocus_angle <= 0) ? camera.look_from : defocus_disk_sample

    //ray_origin := camera.look_from  // NO DOF
    ray_direction := pixel_sample - ray_origin
    ray_time := rand.float64()
    return Ray{ray_origin, ray_direction,ray_time}  
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

render::proc(start:i64,end:i64,camera:Camera,objects:[dynamic]Sphere){

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
    objects: [dynamic]Sphere,
    seed: u64,
}

render_worker :: proc(data: rawptr) {
    job := (^RenderJob)(data)

    rng_state: rand.PCG_Random_State
    context.random_generator = rand.pcg_random_generator(&rng_state)
    rand.reset_u64(job^.seed)

    render(job^.start, job^.end, job^.camera, job^.objects)
}

render_parallel::proc(camera:Camera,objects:[dynamic]Sphere){

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
            objects = objects,
            seed = u64(runtime.read_cycle_counter()) + u64(i) * 7919,
        }
        t := thread.create_and_start_with_data(&jobs[i], render_worker)
        append(&threads, t)
    }

    for t in threads {
        thread.destroy(t)
    }
}