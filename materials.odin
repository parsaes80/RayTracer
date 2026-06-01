package main

import la "core:math/linalg"
import math "core:math"
import rand "core:math/rand"

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
