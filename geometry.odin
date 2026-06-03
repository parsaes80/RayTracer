package main

import la "core:math/linalg"
import math "core:math"
import rand "core:math/rand"
import sort "core:sort"

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

axis_interval::proc(box:aabb,n:int)->Interval{
    if n==1 do return box.y
    if n==2 do return box.z
    return box.x
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

HittableType::enum{Sphere,Quad,BVH}

Hittable:: struct{
    center:Ray,
    radius:f64,
    mat:Material,
    bbox:aabb,
    left:^Hittable,
    right:^Hittable,
    type:HittableType
}

make_sphere_s::proc(static_center:Point,radius:f64,mat:Material)->Hittable{
    rvec := Vec3{radius, radius, radius}
    bbox := make_aabb(static_center - rvec, static_center + rvec)
    return Hittable{Ray{static_center,Vec3{0,0,0},0},radius,mat,bbox,nil,nil,.Sphere}
}

make_sphere_d::proc(center1:Point,center2:Point,radius:f64,mat:Material)->Hittable{
    rvec := Vec3{radius, radius, radius}
    center := Ray{center1,center2-center1,0}
    box1 := make_aabb(ray_at(center,0) - rvec, ray_at(center,0) + rvec)
    box2 := make_aabb(ray_at(center,1) - rvec, ray_at(center,1) + rvec)
    return Hittable{center,radius,mat,make_aabb(box1,box2),nil,nil,.Sphere}
}

make_sphere::proc{make_sphere_s,make_sphere_d}

World::struct{
    bbox:aabb,
    objects:[dynamic]Hittable
}

world_add::proc(world:^World,obj:Hittable){
    append(&world.objects,obj)
    world.bbox = make_aabb(world.bbox,obj.bbox) 
}
make_BVH_Node::proc(objects:[dynamic]Hittable)->Hittable{
    assert(len(objects) > 0)
    return make_BVH_node(objects,0,len(objects))
}
make_BVH_node::proc(objects:[dynamic]Hittable,start:int,end:int)->Hittable{
    assert(end > start)
    axis := rand.int_range(0,3)
    comparator := (axis == 0) ? box_x_compare : (axis == 1) ? box_y_compare: box_z_compare
    node:Hittable
    node.type = .BVH
    object_span := end - start 
    if object_span ==1{
        node.left = &objects[start]
        node.right = &objects[start]
    }
    else if object_span == 2 {
        left_ptr := &objects[start]
        right_ptr := &objects[start+1]
        if comparator(objects[start], objects[start+1]) > 0 {
            left_ptr = &objects[start+1]
            right_ptr = &objects[start]
        }
        node.left = left_ptr
        node.right = right_ptr
    }
    else{
        sort.quick_sort_proc(objects[start:end],comparator)
        mid := start + object_span/2
        node.left = new(Hittable)
        node.left^ = make_BVH_node(objects,start,mid)
        node.right = new(Hittable)
        node.right^ = make_BVH_node(objects,mid,end)
    }
    node.bbox = make_aabb(node.left.bbox,node.right.bbox)
    return node
}

box_compare::proc(a:Hittable,b:Hittable,axis_index:int)->int{
    a_axis_interval := axis_interval(a.bbox,axis_index)
    b_axis_interval := axis_interval(b.bbox,axis_index)
    if a_axis_interval.min < b_axis_interval.min do return -1
    if a_axis_interval.min > b_axis_interval.min do return 1
    return 0
}

box_x_compare::proc(a:Hittable,b:Hittable)->int {return box_compare(a, b, 0)}
box_y_compare::proc(a:Hittable,b:Hittable)->int {return box_compare(a, b, 1)}
box_z_compare::proc(a:Hittable,b:Hittable)->int {return box_compare(a, b, 2)}


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

hit_hittable::proc(obj:Hittable,r:Ray,ray_t:Interval,rec:^HitRecord)->bool{
    if obj.type == .BVH {
        if !hit_aabb(obj.bbox,r,ray_t) do return false
        if obj.left == nil || obj.right == nil do return false

        temp_rec : HitRecord
        hit_anything := false
        closest_so_far := ray_t.max

        if hit(obj.left^, r, Interval{ray_t.min,closest_so_far}, &temp_rec) {
            hit_anything = true
            closest_so_far = temp_rec.t
            rec^ = temp_rec
        }

        if hit(obj.right^, r, Interval{ray_t.min,closest_so_far}, &temp_rec) {
            hit_anything = true
            rec^ = temp_rec
        }

        return hit_anything
    }

    if obj.type == .Sphere{
        current_center := ray_at(obj.center,r.tm)
        oc := current_center- r.orig
        a := la.length2(r.dir)
        h := la.dot(r.dir,oc)
        c := la.length2(oc) -obj.radius*obj.radius
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
        outward_normal : Vec3 = (rec.p - current_center) / obj.radius;
        rec.front_face, rec.normal = set_face_normal(r,outward_normal)
        rec.mat = obj.mat
        return true
    }
    return false
}

hit::proc{hit_aabb,hit_hittable}
