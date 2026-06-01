package main

import la "core:math/linalg"
import math "core:math"
import rand "core:math/rand"

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
