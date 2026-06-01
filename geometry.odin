package main

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

expand::proc(interval:Interval,delta:f64)->Interval {
    padding := delta/2
    return Interval{interval.min - padding, interval.max + padding}
}

make_interval::proc(a:Interval,b:Interval)->Interval{
    res:Interval
    res.min = a.min <= b.min ? a.min : b.min;
    res.max = a.max >= b.max ? a.max : b.max;
    return res
}

empty:Interval: Interval{math.INF_F64,math.NEG_INF_F64}
universe:Interval: Interval{math.NEG_INF_F64,math.INF_F64}

aabb::struct{
    x:Interval,
    y:Interval,
    z:Interval
}

make_aabb_point::proc(a:Point,b:Point)->aabb{
    box:aabb
    box.x = (a[0] <= b[0]) ? Interval{a[0], b[0]} : Interval{b[0], a[0]}
    box.y = (a[1] <= b[1]) ? Interval{a[1], b[1]} : Interval{b[1], a[1]}
    box.z = (a[2] <= b[2]) ? Interval{a[2], b[2]} : Interval{b[2], a[2]}
    return box
}

make_aabb_box::proc(box0:aabb,box1:aabb)->aabb{
    box:aabb
    box.x = make_interval(box0.x, box1.x);
    box.y = make_interval(box0.y, box1.y);
    box.z = make_interval(box0.z, box1.z);
    return box
}

make_aabb::proc{make_aabb_point,make_aabb_box}

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

set_face_normal:: proc(r:Ray,outward_normal:Vec3)->(bool,Vec3){
    front_face := la.dot(r.dir,outward_normal) < 0
    normal := front_face ? outward_normal : -outward_normal
    return front_face,normal
}

ray_at::proc(ray:Ray,t:f64)-> Vec3{
    return ray.orig+t*ray.dir
}

Sphere:: struct{
    center:Ray,
    radius:f64,
    mat:Material,
    bbox:aabb
}

make_sphere_s::proc(static_center:Point,radius:f64,mat:Material)->Sphere{
    rvec := Vec3{radius, radius, radius}
    bbox := make_aabb(static_center - rvec, static_center + rvec)
    return Sphere{Ray{static_center,Vec3{0,0,0},0},radius,mat,bbox}
}

make_sphere_d::proc(center1:Point,center2:Point,radius:f64,mat:Material)->Sphere{
    rvec := Vec3{radius, radius, radius}
    center := Ray{center1,center2-center1,0}
    box1 := make_aabb(ray_at(center,0) - rvec, ray_at(center,0) + rvec)
    box2 := make_aabb(ray_at(center,1) - rvec, ray_at(center,1) + rvec)
    return Sphere{center,radius,mat,make_aabb(box1,box2)}
}

make_sphere::proc{make_sphere_s,make_sphere_d}

World::struct{
    bbox:aabb,
    objects:[dynamic]Hittable
}

world_add::proc(world:^World,obj:Hittable){
    append(&world.objects,obj)
    world.bbox = obj.(Sphere).bbox
}

Hittable::union{Sphere}

BVH_node::struct{
    left:^Hittable,
    right:^Hittable,
    bbox:aabb
}

hit_all:: proc(r:Ray, ray_t:Interval,rec:^HitRecord,objects:[dynamic]Hittable)->bool{
    temp_rec : HitRecord
    hit_anything:bool = false;
    closest_so_far:f64 = ray_t.max;

    for obj  in objects {
        if hit(obj,r, Interval{ray_t.min,closest_so_far}, &temp_rec) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec^ = temp_rec;
        }
    }
    return hit_anything;
}

hit_sphere::proc(obj:Hittable,r:Ray,ray_t:Interval,rec:^HitRecord)->bool{
    switch sphere in obj{
        case Sphere:
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
    return true
}

hit::proc{hit_aabb,hit_sphere}
