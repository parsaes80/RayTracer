package main

import la "core:math/linalg"
import math "core:math"
import rand "core:math/rand"

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

    pixel_delta_u := viewport_u / WIDTH
    pixel_delta_v := viewport_v / HEIGHT

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

get_ray::proc(i:i64,j:i64,camera:Camera)->Ray{
    offset:= Vec3{rand.float64()-0.5,rand.float64()-0.5,0}

    pixel_sample := camera.pixel00_loc +
    ((f64(i)+offset.x)*camera.pixel_delta_u) +
    (((f64(j)+offset.y)*camera.pixel_delta_v))

    p := random_in_unit_disk()
    defocus_disk_sample:= camera.look_from + (p[0] * camera.defocus_disk_u) + (p[1] * camera.defocus_disk_v);
    ray_origin := (camera.defocus_angle <= 0) ? camera.look_from : defocus_disk_sample

    ray_direction := pixel_sample - ray_origin
    ray_time := rand.float64()
    return Ray{ray_origin, ray_direction,ray_time}
}
