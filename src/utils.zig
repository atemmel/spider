pub fn clamp(value: i32, min: i32, max: i32) i32 {
    if(value < min) {
        return min;
    } else if(value > max) {
        return max;
    }
    return value;
}
