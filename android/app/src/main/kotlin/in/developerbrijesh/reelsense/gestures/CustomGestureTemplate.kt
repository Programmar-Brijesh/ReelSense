package `in`.developerbrijesh.reelsense.gestures

import org.json.JSONArray
import org.json.JSONObject

data class CustomGestureTemplate(
    val id: String,
    val name: String,
    val action: String,
    val landmarks: List<Point3D>,
    val sampleCount: Int = 25,
    val confidenceThreshold: Float = 0.82f,
    val isEnabled: Boolean = true
) {
    companion object {
        fun fromJson(jsonStr: String, id: String, name: String, action: String, threshold: Float, enabled: Boolean): CustomGestureTemplate? {
            return try {
                val array = JSONArray(jsonStr)
                val points = ArrayList<Point3D>(array.length())
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    points.add(
                        Point3D(
                            x = obj.getDouble("x").toFloat(),
                            y = obj.getDouble("y").toFloat(),
                            z = obj.getDouble("z").toFloat()
                        )
                    )
                }
                if (points.size < 21) return null
                CustomGestureTemplate(
                    id = id,
                    name = name,
                    action = action,
                    landmarks = points,
                    confidenceThreshold = threshold,
                    isEnabled = enabled
                )
            } catch (_: Exception) {
                null
            }
        }

        fun landmarksToJson(landmarks: List<Point3D>): String {
            val array = JSONArray()
            for (p in landmarks) {
                val obj = JSONObject().apply {
                    put("x", p.x)
                    put("y", p.y)
                    put("z", p.z)
                }
                array.put(obj)
            }
            return array.toString()
        }
    }
}
