package raytacer

import "core:fmt"
import sdl "vendor:sdl3"
import la "core:math/linalg"
import math "core:math"

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

empty:Interval: Interval{math.INF_F64,math.NEG_INF_F64}
universe:Interval: Interval{math.NEG_INF_F64,math.INF_F64}

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

set_face_normal:: proc(r:Ray,outward_normal:Vec3)->(bool,Vec3){
    front_face := la.dot(r.dir,outward_normal) < 0
    normal := front_face ? outward_normal : -outward_normal
    return front_face,normal
}

ray_at::proc(ray:Ray,t:f64)-> Vec3{
    return ray.orig+t*ray.dir
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
    oc := sphere.center - r.orig
    a := la.dot(r.dir,r.dir)
    h := la.dot(r.dir,oc) 
    c := la.dot(oc,oc) -sphere.radius*sphere.radius
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
    outward_normal : Vec3 = (rec.p - sphere.center) / sphere.radius;
    rec.front_face, rec.normal = set_face_normal(r,outward_normal)

    return true
}

ray_color::proc(r:Ray,objects:[dynamic]Sphere)->Color{
    rec:HitRecord
    if hit_all(r, Interval{0,math.INF_F64}, &rec,objects) {
        return 0.5 * (rec.normal + Color{1,1,1})
    }
    unit_direction := la.normalize(r.dir)
    a := 0.5*(unit_direction.y + 1.0)
    return (1.0-a)*Color{1.0, 1.0, 1.0} + a*Color{0.5, 0.7, 1.0}
}

write_color ::proc (pixel_color:Color) -> u32{
    intensity := Interval{0.0,0.99999}
    ir := u32(255.999 * interval_clamp(intensity,pixel_color.r))
    ig := u32(255.999 * interval_clamp(intensity,pixel_color.g))
    ib := u32(255.999 * interval_clamp(intensity,pixel_color.b))
    return (ir << 24) | (ig << 16) | (ib << 8) | 0xFF
}

Camera::struct{
    aspect_ratio:f64,
    image_height:i64, 
    image_width:i64,
    center:Point,        // Camera center
    pixel_delta_u:Vec3,   // Offset to pixel to the right
    pixel_delta_v:Vec3,   // Offset to pixel below
    pixel00_loc:Point,   // Location of pixel 0, 0
}

create_camera::proc()->Camera{
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

    return Camera{ASPECT_RATIO,HEIGHT,WIDTH,camera_center,pixel_delta_u,pixel_delta_v,pixel00_loc}
}

render::proc(camera:^Camera,objects:[dynamic]Sphere){
    for j := 0; j < HEIGHT; j+=1 {
        for i := 0; i < WIDTH; i+=1 {
            pixel_center := camera.pixel00_loc + (f64(i) * camera.pixel_delta_u) + (f64(j) * camera.pixel_delta_v);
            ray_direction := pixel_center - camera.center;
            r:= Ray{camera.center, ray_direction};

            pixel_color := ray_color(r,objects);
            Framebuffer[j][i] = write_color(pixel_color)
        }
    }
}