# Prepara o audio do jogo a partir dos arquivos crus de docs/audio/.
#
#   assets/audio/musica_lastro.mp3    196 s   fundo musical, em laco
#   assets/audio/passo_1..7.wav      ~0,22 s  uma pisada cada, para variacao
#   assets/audio/martelada.wav       ~0,40 s  o golpe da picareta
#   assets/audio/porta_abrindo.wav   ~0,45 s  porta automatica abrindo
#   assets/audio/porta_fechando.wav  ~0,45 s  a MESMA, ao contrario
#
# POR QUE ESTE GERADOR EXISTE
#
# docs/* esta no .gitignore (so .md e .html passam), entao arquivo cru em
# docs/audio/ nunca entraria num commit — o jogo carregaria audio que o
# repositorio nao tem. assets/ e versionado, e e de la que o jogo le. Mas
# copiar na mao esconderia os cortes que o audio cru EXIGE, e e isso que as
# secoes abaixo registram.
#
# POR QUE WAV NOS EFEITOS, E MP3 SO NA MUSICA
#
# MP3 e por quadro: o decodificador devolve alguns milissegundos de silencio que
# o codificador acrescentou, e metal-hammer-hit.mp3 tem 70 ms deles. Num som
# percussivo casado com um quadro de animacao, 70 ms e atraso que se ouve — o
# golpe sai depois da faisca. WAV nao tem esse preambulo, carrega inteiro na
# memoria e nao gasta CPU decodificando a cada toque, que e o que se quer de um
# efeito curto disparado varias vezes por segundo.
#
# A musica fica em MP3 pelo motivo inverso: 196 s em WAV sao ~75 MB contra 7,8
# do MP3, e latencia de decodificacao de faixa continua nao importa. Ela e
# COPIADA sem reprocessar — reexportar um MP3 de 320 kbps perde qualidade e nao
# ganha nada.
#
# POR QUE A PISADA E FATIADA
#
# footstep.mp3 nao e uma pisada: sao SETE, espacadas 0,54 s, uma gravacao de
# alguem andando. Tocar o arquivo inteiro em laco enquanto o jogador anda foi a
# primeira ideia e esta errada — a cadencia da animacao e puxada pela distancia
# percorrida (ver ANDAR_PASSADA_EM_PIXELS em scripts/jogador.gd), e na
# velocidade cheia da quase 4 pisadas por segundo, mais que o dobro da gravacao.
# Som e imagem andariam separados, e o pe no chao nao casaria com nada.
#
# Fatiado, cada quadro de contato da animacao dispara UMA pisada, e as sete
# viram variacao no AudioStreamRandomizer de scripts/som.gd: a mesma amostra
# repetida quatro vezes por segundo le como metralhadora.
#
# A JANELA DA PISADA E CURTA DE PROPOSITO
#
# Cada pisada da gravacao cai a 2% do pico em 80-170 ms, mas o arquivo deixa
# 0,54 s de ar depois dela. Na cadencia do jogo — uma pisada a cada 0,26 s —
# guardar esse ar deixaria tres amostras soando juntas, e o passo viraria
# arrasto. 0,22 s cobre a cauda audivel de todas as sete e acaba antes da
# proxima.
#
# POR QUE A PORTA FECHANDO E A MESMA AMOSTRA INVERTIDA
#
# Foi o pedido, e e truque conhecido de desenho de som: o perfil de
# open-door.mp3 e um crescendo ate o pico com queda curta, entao ao contrario
# ele vira entrada suave que termina em batida seca — que e a leitura de uma
# folha encostando no batente. Nao ha gravacao de fechamento, e inverter custa
# uma linha.
import os
import shutil
import subprocess
import wave

import numpy as np

ENTRADA = "docs/audio"
SAIDA = "assets/audio"

## A musica so e copiada: ver o cabecalho.
MUSICA_CRUA = "scraptronaut-audio-1.mp3"
MUSICA = "musica_lastro.mp3"

## Acima deste pico, em fracao da escala cheia, uma janela de 10 ms conta como
## comeco de pisada. Os picos da gravacao passam de 0,80 e o ar entre elas fica
## abaixo de 0,01 — qualquer valor no meio serve, e 0,06 tem folga dos dois
## lados.
LIMITE_PISADA: float = 0.06

## Quanto antes do limite a fatia comeca. O limite e cruzado alguns
## milissegundos DEPOIS do ataque de verdade, e cortar no cruzamento decapita a
## batida: sai estalo em vez de pe no chao.
ANTES: float = 0.008

## Janela de cada pisada, e quanto dela e esvaziado no fim. A saida existe para
## nao cortar no meio da onda: corte seco em amostra diferente de zero e um
## clique, e com cauda ainda audivel o clique fica mais alto que a pisada.
PISADA: float = 0.22
PISADA_SAIDA: float = 0.03

## Martelada: quanto guardar depois do ataque. O golpe cru cai a 2% em 0,25 s e
## o resto do arquivo e silencio puro — 0,40 s cobre a cauda com sobra.
MARTELADA: float = 0.40
MARTELADA_SAIDA: float = 0.06

## Abaixo disto e silencio de borda, e sai. Mais baixo que LIMITE_PISADA de
## proposito: aqui nao se procura um ataque, se procura onde o arquivo
## realmente comeca, e o crescendo da porta nasce em 0,002.
LIMITE_SILENCIO: float = 0.0015

## Entrada curta em toda amostra aparada. Comecar numa amostra diferente de zero
## poe um salto de tensao na saida da placa, que se ouve como toque seco antes
## do som.
ENTRADA_CURTA: float = 0.002


def _ler(caminho: str) -> tuple:
	"""Decodifica um arquivo de audio em (amostras, taxa, canais).

	As amostras saem em float de -1 a 1, numa matriz de (quadros, canais). Quem
	decodifica e o ffmpeg porque nenhuma biblioteca de Python instalada aqui le
	MP3 — e ele ja esta no PATH.
	"""
	sonda = subprocess.run(
		[
			"ffprobe", "-v", "error",
			"-select_streams", "a:0",
			"-show_entries", "stream=sample_rate,channels",
			"-of", "csv=p=0",
			caminho,
		],
		capture_output=True, text=True, check=True,
	)
	taxa_texto, canais_texto = sonda.stdout.strip().split(",")[:2]
	taxa = int(taxa_texto)
	canais = int(canais_texto)

	cru = subprocess.run(
		["ffmpeg", "-v", "error", "-i", caminho, "-f", "s16le", "-acodec", "pcm_s16le", "-"],
		capture_output=True, check=True,
	).stdout
	amostras = np.frombuffer(cru, dtype="<i2").astype(np.float32) / 32768.0
	return amostras.reshape(-1, canais), taxa, canais


def _escrever(nome: str, dados: np.ndarray, taxa: int) -> None:
	"""Grava WAV de 16 bits. Godot importa isso sem conversao nenhuma."""
	inteiros = np.round(np.clip(dados, -1.0, 1.0) * 32767.0).astype("<i2")
	caminho = os.path.join(SAIDA, nome)
	with wave.open(caminho, "wb") as arquivo:
		arquivo.setnchannels(dados.shape[1])
		arquivo.setsampwidth(2)
		arquivo.setframerate(taxa)
		arquivo.writeframes(inteiros.tobytes())
	print("gerado: %s/%s (%.3f s, %d canais, %d Hz)" % (
		SAIDA, nome, len(dados) / taxa, dados.shape[1], taxa
	))


def _envoltoria(dados: np.ndarray, taxa: int, janela: float) -> np.ndarray:
	"""Pico absoluto de cada janela, com os canais somados pelo maior."""
	largura = max(1, int(taxa * janela))
	mono = np.max(np.abs(dados), axis=1)
	sobra = len(mono) % largura
	if sobra:
		mono = mono[:-sobra]
	return np.max(mono.reshape(-1, largura), axis=1)


def _moldar(dados: np.ndarray, taxa: int, entrada: float, saida: float) -> np.ndarray:
	"""Entrada e saida lineares nas bordas, para nao estalar."""
	moldado = dados.copy()
	n_entrada = min(len(moldado), int(taxa * entrada))
	if n_entrada > 1:
		moldado[:n_entrada] *= np.linspace(0.0, 1.0, n_entrada, dtype=np.float32)[:, None]
	n_saida = min(len(moldado), int(taxa * saida))
	if n_saida > 1:
		moldado[-n_saida:] *= np.linspace(1.0, 0.0, n_saida, dtype=np.float32)[:, None]
	return moldado


def _primeiro_som(dados: np.ndarray, limite: float) -> int:
	"""Primeiro quadro acima de `limite`, ou zero se o arquivo e todo silencio."""
	acima = np.nonzero(np.max(np.abs(dados), axis=1) > limite)[0]
	return int(acima[0]) if len(acima) else 0


def _ultimo_som(dados: np.ndarray, limite: float) -> int:
	acima = np.nonzero(np.max(np.abs(dados), axis=1) > limite)[0]
	return int(acima[-1]) + 1 if len(acima) else len(dados)


def _achar_pisadas(dados: np.ndarray, taxa: int) -> list:
	"""Quadro de inicio de cada pisada da gravacao.

	Mede, nao assume: trocar footstep.mp3 por outra gravacao muda o numero de
	fatias e o espacamento sem mexer em nada aqui. Uma lista de tempos escrita a
	mao daria arquivos errados em silencio.
	"""
	janela = 0.01
	envoltoria = _envoltoria(dados, taxa, janela)
	inicios: list = []
	tocando = False
	for i, pico in enumerate(envoltoria):
		if pico > LIMITE_PISADA and not tocando:
			inicios.append(max(0, int((i * janela - ANTES) * taxa)))
			tocando = True
		elif pico < LIMITE_PISADA * 0.5 and tocando:
			tocando = False
	return inicios


def gerar_musica() -> None:
	destino = os.path.join(SAIDA, MUSICA)
	shutil.copyfile(os.path.join(ENTRADA, MUSICA_CRUA), destino)
	print("copiado: %s (%.1f MB)" % (destino, os.path.getsize(destino) / 1048576.0))


def gerar_pisadas() -> None:
	dados, taxa, _ = _ler(os.path.join(ENTRADA, "footstep.mp3"))
	comprimento = int(taxa * PISADA)
	for numero, inicio in enumerate(_achar_pisadas(dados, taxa), start=1):
		fatia = dados[inicio:inicio + comprimento]
		_escrever("passo_%d.wav" % numero, _moldar(fatia, taxa, ENTRADA_CURTA, PISADA_SAIDA), taxa)


def gerar_martelada() -> None:
	dados, taxa, _ = _ler(os.path.join(ENTRADA, "metal-hammer-hit.mp3"))
	inicio = max(0, _primeiro_som(dados, LIMITE_SILENCIO) - int(taxa * ANTES))
	fatia = dados[inicio:inicio + int(taxa * MARTELADA)]
	_escrever("martelada.wav", _moldar(fatia, taxa, ENTRADA_CURTA, MARTELADA_SAIDA), taxa)


def gerar_porta() -> None:
	dados, taxa, _ = _ler(os.path.join(ENTRADA, "open-door.mp3"))
	aparada = dados[_primeiro_som(dados, LIMITE_SILENCIO):_ultimo_som(dados, LIMITE_SILENCIO)]
	_escrever("porta_abrindo.wav", _moldar(aparada, taxa, ENTRADA_CURTA, PISADA_SAIDA), taxa)
	# ::-1 inverte os QUADROS, nao os canais: o par estereo continua no lugar.
	_escrever("porta_fechando.wav", _moldar(aparada[::-1], taxa, ENTRADA_CURTA, PISADA_SAIDA), taxa)


def main() -> None:
	os.makedirs(SAIDA, exist_ok=True)
	gerar_musica()
	gerar_pisadas()
	gerar_martelada()
	gerar_porta()


if __name__ == "__main__":
	main()
