extends AudioStreamPlayer

# Включает зацикливание (для OGG/MP3) и запускает воспроизведение.

func _ready() -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	play()