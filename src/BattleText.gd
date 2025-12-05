extends Node
class_name BattleText

# ここを全部「const」にするのがポイントです
const BATTLE_AIKO := [
	"「焦らないで…影もこっちを見てる。\n　次の一手で流れをつかむんだ…！」",
	"「うん、大丈夫。まだ様子を見るだけ…。\n　ここから、ちゃんと立て直せるはず。」"
]

const BATTLE_INEFFECTIVE := [
	"「えっ…!? 当たったのに、ぜんぜん効いてない…！\n　この影、普通の一撃じゃ崩せない…？」",
	"「……ダメだ、手応えがない。\n　なにか…なにか別の力で押し返されてる…！」"
]

const BATTLE_INEFFECTIVE_START := "「……っ!? 茶器の中の光まで、引きずり出されてる…！\n　からだが、どんどん冷たくなっていく……！」"

const BATTLE_MISS := [
	"「えっ…外れた!? 影の動き、すごく早い……。\n　気を引き締めないと…！」",
	"「しまった…読み違えた……。\n　でも、まだ立て直せる…！」"
]

const BATTLE_CRITICAL_WIN := [
	"「今だっ…！ 光よ、もっと強く！！\n　——これなら、影を押し返せる！」",
	"「やった…！ この一撃は、絶対無駄じゃない……。\n　みんなの灯りを守れる…！」"
]

const BATTLE_CRITICAL_LOSE := [
	"「きゃああっ！！　そんなの…ずるいよ……っ！\n　身体じゅうが、痛くて…震えが止まらない……！」",
	"「あああっ…！　っつ……！ こんな一撃…聞いてないってば……。\n　でも…まだ…まだ倒れたくない…！」"
]

const BATTLE_NORMAL_WIN := [
	"「よし…！ 思いが届いた……。\n　みんなのためにも、このまま押し切る！」"
]

const BATTLE_NORMAL_LOSE := [
	"「きゃっ…！ いったぁ……っ！！\n　うう…でも…まだ、立てる……。ここで下がったら終わりだもん…！」"
]

const BATTLE_FINAL_WIN := [
	"「これで…終わらせる…！\n　みんなの居場所を、必ず守る…！！」"
]

const BATTLE_FINAL_LOSE := [
	"「うっ…！ でも、ここで負けたら、\n　みんなの灯りが消えちゃう…！　まだ倒れない…！」"
]

const BATTLE_WIN_FINAL := [
	"「……終わった。\n　光が、また一つ戻ってきたね。」"
]

const BATTLE_LOSE_FINAL := [
	"「……もう…起き上がれないや……。\n　ごめんね、みんな……ここまでが…わたしの精一杯、だった……。」"
]

const BATTLE_DRAW := [
	"「……こんな終わり方、嫌なのに……。\n　それでも…誰かの心に、少しでも灯りが残ってくれたなら……。」"
]


# ラウンド結果から「短い結果」と「長文」をまとめて返す
static func get_round_text(
	game_stage: int,
	round_result: int,   # 0=あいこ,1=勝ち,2=負け
	miss: bool,
	critical: bool,
	ineffective: bool,
	start_drain: bool,
	player_hp: int,
	enemy_hp: int
) -> Dictionary:
	var result_msg := ""
	var battle_msg := ""

	# --- あいこ ---
	if round_result == 0:
		battle_msg = BATTLE_AIKO.pick_random()
		result_msg = "あいこ…静かに構えた。"

	# --- 効かない（ステージ6） ---
	elif ineffective:
		battle_msg = BATTLE_INEFFECTIVE.pick_random()
		result_msg = "……効いてない…!?"
		if start_drain:
			battle_msg = BATTLE_INEFFECTIVE_START
			result_msg = "敵の力が暴走した…！"

	# --- ミス ---
	elif miss:
		battle_msg = BATTLE_MISS.pick_random()
		result_msg = "ミス！ 攻撃は外れた…！"

	# --- クリティカル（勝ち） ---
	elif critical and round_result == 1:
		battle_msg = BATTLE_CRITICAL_WIN.pick_random()
		result_msg = "クリティカル！ 大きな一撃！"

	# --- クリティカル（負け） ---
	elif critical and round_result == 2:
		battle_msg = BATTLE_CRITICAL_LOSE.pick_random()
		result_msg = "クリティカル… 大ダメージを受けた！"

	# --- 通常勝ち ---
	elif round_result == 1:
		battle_msg = BATTLE_NORMAL_WIN.pick_random()
		result_msg = "攻撃が命中！"

	# --- 通常負け ---
	elif round_result == 2:
		battle_msg = BATTLE_NORMAL_LOSE.pick_random()
		result_msg = "攻撃を受けてしまった…！"

	# ステージ7の上書き
	if game_stage == 7 and enemy_hp > 0 and player_hp > 0:
		if round_result == 1 and not miss and not ineffective:
			battle_msg = BATTLE_FINAL_WIN.pick_random()
		elif round_result == 2 and not miss:
			battle_msg = BATTLE_FINAL_LOSE.pick_random()

	# 勝敗確定（ここで上書き）
	if enemy_hp <= 0 and player_hp > 0:
		result_msg = "勝利！"
		battle_msg = BATTLE_WIN_FINAL[0]
	elif player_hp <= 0 and enemy_hp > 0:
		result_msg = "敗北…"
		battle_msg = BATTLE_LOSE_FINAL[0]
	elif player_hp <= 0 and enemy_hp <= 0:
		result_msg = "相打ち…"
		battle_msg = BATTLE_DRAW[0]

	return {
		"result_msg": result_msg,
		"battle_msg": battle_msg
	}
