package com.frito.music

import android.content.Context
import android.media.audiofx.Equalizer

data class EqBand(
    val index: Short,
    val centerFreqHz: Int,
    val minLevel: Short,
    val maxLevel: Short,
    var currentLevel: Short
) {
    fun toMap(): Map<String, Any> = mapOf(
        "index" to index.toInt(),
        "centerFreqHz" to centerFreqHz,
        "minLevel" to minLevel.toInt(),
        "maxLevel" to maxLevel.toInt(),
        "currentLevel" to currentLevel.toInt()
    )
}

data class EqPreset(
    val index: Short,
    val name: String
) {
    fun toMap(): Map<String, Any> = mapOf(
        "index" to index.toInt(),
        "name" to name
    )
}

class EqualizerManager(private val context: Context) {
    private var equalizer: Equalizer? = null
    private val prefs = context.getSharedPreferences("equalizer_prefs", Context.MODE_PRIVATE)

    var isEnabled: Boolean = prefs.getBoolean("is_enabled", false)
        private set

    var bands: List<EqBand> = emptyList()
        private set

    var presets: List<EqPreset> = emptyList()
        private set

    var selectedPreset: Short = prefs.getInt("selected_preset", -1).toShort()
        private set

    fun attachAudioSession(audioSessionId: Int) {
        release()
        try {
            equalizer = Equalizer(0, audioSessionId).apply {
                enabled = isEnabled

                val numBands = numberOfBands
                val bandLevelRange = bandLevelRange
                val minLvl = bandLevelRange[0]
                val maxLvl = bandLevelRange[1]

                bands = (0 until numBands).map { i ->
                    val idx = i.toShort()
                    val centerFreq = getCenterFreq(idx) / 1000 // Convert mHz to Hz
                    val savedLevel = prefs.getInt("band_$idx", getBandLevel(idx).toInt()).toShort()
                    setBandLevel(idx, savedLevel)
                    EqBand(
                        index = idx,
                        centerFreqHz = centerFreq,
                        minLevel = minLvl,
                        maxLevel = maxLvl,
                        currentLevel = savedLevel
                    )
                }

                val numPresets = numberOfPresets
                val list = mutableListOf<EqPreset>()
                list.add(EqPreset(-1, "Personalizado"))
                for (i in 0 until numPresets) {
                    list.add(EqPreset(i.toShort(), getPresetName(i.toShort())))
                }
                presets = list

                if (selectedPreset.toInt() != -1 && selectedPreset < numPresets) {
                    usePreset(selectedPreset)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun release() {
        equalizer?.release()
        equalizer = null
    }

    fun setEnabled(enabled: Boolean) {
        isEnabled = enabled
        equalizer?.enabled = enabled
        prefs.edit().putBoolean("is_enabled", enabled).apply()
    }

    fun setBandLevel(bandIndex: Short, level: Short) {
        equalizer?.setBandLevel(bandIndex, level)
        bands.find { it.index == bandIndex }?.currentLevel = level
        prefs.edit().putInt("band_$bandIndex", level.toInt()).apply()
        selectedPreset = (-1).toShort()
        prefs.edit().putInt("selected_preset", -1).apply()
    }

    fun usePreset(presetIndex: Short) {
        if (presetIndex.toInt() == -1) return
        equalizer?.usePreset(presetIndex)
        selectedPreset = presetIndex
        prefs.edit().putInt("selected_preset", presetIndex.toInt()).apply()

        equalizer?.let { eq ->
            for (band in bands) {
                val lvl = eq.getBandLevel(band.index)
                band.currentLevel = lvl
                prefs.edit().putInt("band_${band.index}", lvl.toInt()).apply()
            }
        }
    }

    fun getData(): Map<String, Any> {
        return mapOf(
            "isEnabled" to isEnabled,
            "selectedPreset" to selectedPreset.toInt(),
            "bands" to bands.map { it.toMap() },
            "presets" to presets.map { it.toMap() }
        )
    }
}
