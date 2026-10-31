package `in`.developerbrijesh.reelsense.gestures

import kotlin.math.sqrt

data class Point3D(
    val x: Float,
    val y: Float,
    val z: Float
) {
    fun distanceTo(other: Point3D): Float {
        val dx = this.x - other.x
        val dy = this.y - other.y
        val dz = (this.z - other.z) * 0.5f // downscale z noise from monocular camera
        return sqrt((dx * dx) + (dy * dy) + (dz * dz))
    }
}
