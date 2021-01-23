=begin
All types except Shadow have Shadow as a weakness.
Shadow has Shadow as a resistance.
On a side note, the Shadow moves in Colosseum will not be affected by Weaknesses
or Resistances, while in XD the Shadow-type is Super-Effective against all other
types.
2/5 - display nature

XD - Shadow Rush -- 55, 100 - Deals damage.
Colosseum - Shadow Rush -- 90, 100
If this attack is successful, user loses half of HP lost by opponent due to this
attack (recoil). If user is in Hyper Mode, this attack has a good chance for a
critical hit.
=end

#===============================================================================
# Purify a Shadow Pokémon.
#===============================================================================
def pbPurify(pokemon,scene)
  return if pokemon.heartgauge!=0 || !pokemon.shadow
  return if !pokemon.savedev && !pokemon.savedexp
  pokemon.shadow = false
  pokemon.giveRibbon(PBRibbons::NATIONAL)
  scene.pbDisplay(_INTL("{1} opened the door to its heart!",pokemon.name))
  old_moves = []
  pokemon.moves.each { |m| old_moves.push(m.id) }
  pokemon.pbUpdateShadowMoves
  pokemon.moves.each_with_index do |m, i|
    next if m == old_moves[i]
    scene.pbDisplay(_INTL("{1} regained the move {2}!", pokemon.name, m.name))
  end
  pokemon.pbRecordFirstMoves
  if pokemon.savedev
    for i in 0...6
      pbApplyEVGain(pokemon,i,pokemon.savedev[i])
    end
    pokemon.savedev = nil
  end
  newexp = PBExperience.pbAddExperience(pokemon.exp,pokemon.savedexp||0,pokemon.growth_rate)
  pokemon.savedexp = nil
  newlevel = PBExperience.pbGetLevelFromExperience(newexp,pokemon.growth_rate)
  curlevel = pokemon.level
  if newexp!=pokemon.exp
    scene.pbDisplay(_INTL("{1} regained {2} Exp. Points!",pokemon.name,newexp-pokemon.exp))
  end
  if newlevel==curlevel
    pokemon.exp = newexp
    pokemon.calcStats
  else
    pbChangeLevel(pokemon,newlevel,scene) # for convenience
    pokemon.exp = newexp
  end
  if scene.pbConfirm(_INTL("Would you like to give a nickname to {1}?", pokemon.speciesName))
    newname = pbEnterPokemonName(_INTL("{1}'s nickname?", pokemon.speciesName),
                                 0, Pokemon::MAX_NAME_SIZE, "", pokemon)
    pokemon.name = newname
  end
end

def pbApplyEVGain(pokemon,ev,evgain)
  totalev = 0
  for i in 0...6
    totalev += pokemon.ev[i]
  end
  if totalev+evgain>Pokemon::EV_LIMIT   # Can't exceed overall limit
    evgain -= totalev+evgain-Pokemon::EV_LIMIT
  end
  if pokemon.ev[ev]+evgain>Pokemon::EV_STAT_LIMIT
    evgain -= totalev+evgain-Pokemon::EV_STAT_LIMIT
  end
  if evgain>0
    pokemon.ev[ev] += evgain
  end
end

def pbReplaceMoves(pkmn, new_moves)
  return if !pkmn
  new_moves.each do |move|
    next if !move || pkmn.hasMove?(move)
    # Find a move slot to put move into
    for i in 0...Pokemon::MAX_MOVES
      if i >= pkmn.numMoves
        # Empty slot; add the new move there
        pkmn.pbLearnMove(move)
        break
      elsif !new_moves.include?(pkmn.moves[i].id)
        # Known move that isn't a move to be relearned; replace it
        pkmn.moves[i].id = move
        break
      end
    end
  end
end



#===============================================================================
# Relic Stone scene.
#===============================================================================
class RelicStoneScene
  def pbPurify
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbDisplay(msg,brief=false)
    UIHelper.pbDisplay(@sprites["msgwindow"],msg,brief) { pbUpdate }
  end

  def pbConfirm(msg)
    UIHelper.pbConfirm(@sprites["msgwindow"],msg) { pbUpdate }
  end

  def pbStartScene(pokemon)
    @sprites = {}
    @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z = 99999
    @pokemon = pokemon
    addBackgroundPlane(@sprites,"bg","relicstonebg",@viewport)
    @sprites["msgwindow"] = Window_AdvancedTextPokemon.new("")
    @sprites["msgwindow"].viewport = @viewport
    @sprites["msgwindow"].x        = 0
    @sprites["msgwindow"].y        = Graphics.height-96
    @sprites["msgwindow"].width    = Graphics.width
    @sprites["msgwindow"].height   = 96
    @sprites["msgwindow"].text     = ""
    @sprites["msgwindow"].visible  = true
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end
end



class RelicStoneScreen
  def initialize(scene)
    @scene = scene
  end

  def pbDisplay(x)
    @scene.pbDisplay(x)
  end

  def pbConfirm(x)
    @scene.pbConfirm(x)
  end

  def pbUpdate; end

  def pbRefresh; end

  def pbStartScreen(pokemon)
    @scene.pbStartScene(pokemon)
    @scene.pbPurify
    pbPurify(pokemon,self)
    @scene.pbEndScene
  end
end



def pbRelicStoneScreen(pkmn)
  retval = true
  pbFadeOutIn {
    scene = RelicStoneScene.new
    screen = RelicStoneScreen.new(scene)
    retval = screen.pbStartScreen(pkmn)
  }
  return retval
end



#===============================================================================
#
#===============================================================================
def pbIsPurifiable?(pkmn)
  return false if !pkmn
  return false if pkmn.isSpecies?(:LUGIA)
  return false if !pkmn.shadowPokemon? || pkmn.heartgauge>0
  return true
end

def pbHasPurifiableInParty?
  return $Trainer.party.any? { |pkmn| pbIsPurifiable?(pkmn) }
end

def pbRelicStone
  if !pbHasPurifiableInParty?
    pbMessage(_INTL("You have no Pokémon that can be purified."))
    return
  end
  pbMessage(_INTL("There's a Pokémon that may open the door to its heart!"))
  # Choose a purifiable Pokemon
  pbChoosePokemon(1,2,proc { |pkmn|
    !pkmn.egg? && pkmn.hp>0 && pkmn.shadowPokemon? && pkmn.heartgauge==0
  })
  if $game_variables[1]>=0
    pbRelicStoneScreen($Trainer.party[$game_variables[1]])
  end
end

def pbReadyToPurify(pkmn)
  return unless pkmn && pkmn.shadowPokemon?
  pkmn.pbUpdateShadowMoves
  if pkmn.heartgauge==0
    pbMessage(_INTL("{1} can now be purified!",pkmn.name))
  end
end



#===============================================================================
# Pokémon class.
#===============================================================================
class Pokemon
  attr_writer   :heartgauge
  attr_accessor :shadow
  attr_writer   :hypermode
  attr_accessor :savedev
  attr_accessor :savedexp
  attr_accessor :shadowmoves
  attr_accessor :shadowmovenum
  HEARTGAUGESIZE = 3840

  alias :__shadow_expeq :exp=
  def exp=(value)
    if shadowPokemon?
      @savedexp += value-self.exp
    else
      __shadow_expeq(value)
    end
  end

  alias :__shadow_hpeq :hp=
  def hp=(value)
    __shadow_hpeq(value)
    @hypermode = false if value<=0
  end

  def hypermode
    return (self.heartgauge==0 || self.hp==0) ? false : @hypermode
  end

  def heartgauge
    return @heartgauge || 0
  end

  def heartStage
    return 0 if !@shadow
    hg = HEARTGAUGESIZE/5.0
    return ([self.heartgauge,HEARTGAUGESIZE].min/hg).ceil
  end

  def adjustHeart(value)
    return if !@shadow
    @heartgauge = 0 if !@heartgauge
    @heartgauge += value
    @heartgauge = HEARTGAUGESIZE if @heartgauge>HEARTGAUGESIZE
    @heartgauge = 0 if @heartgauge<0
  end

  def shadowPokemon?
    return @shadow && @heartgauge && @heartgauge>=0
  end
  alias :isShadow? :shadowPokemon?

  def makeShadow
    self.shadow      = true
    self.heartgauge  = HEARTGAUGESIZE
    self.savedexp    = 0
    self.savedev     = [0,0,0,0,0,0]
    self.shadowmoves = []
    # Retrieve Shadow moveset for this Pokémon
    shadow_moveset = pbLoadShadowMovesets[species_data.id]
    shadow_moveset = pbLoadShadowMovesets[@species] if !shadow_moveset || shadow_moveset.length == 0
    # Record this Pokémon's Shadow moves
    if shadow_moveset && shadow_moveset.length > 0
      for i in 0...[shadow_moveset.length, MAX_MOVES].min
        self.shadowmoves[i] = shadow_moveset[i]
      end
      self.shadowmovenum = shadow_moveset.length
    else
      # No Shadow moveset defined; just use Shadow Rush
      self.shadowmoves[0] = :SHADOWRUSH if GameData::Move.exists?(:SHADOWRUSH)
      self.shadowmovenum = 1
    end
    # Record this Pokémon's original moves
    @moves.each_with_index { |m, i| self.shadowmoves[MAX_MOVES + i] = m.id }
    # Update moves
    pbUpdateShadowMoves
  end

  def pbUpdateShadowMoves(relearn_all_moves = false)
    return if !@shadowmoves
    # Not a Shadow Pokémon (any more); relearn all its original moves
    if !@shadow
      if @shadowmoves.length > MAX_MOVES
        new_moves = []
        @shadowmoves.each_with_index { |m, i| new_moves.push(m) if m && i >= MAX_MOVES }
        pbReplaceMoves(self, new_moves)
      end
      @shadowmoves = nil
      return
    end
    # Is a Shadow Pokémon; ensure it knows the appropriate moves depending on its heart stage
    m = @shadowmoves
    # Start with all Shadow moves
    new_moves = []
    @shadowmoves.each_with_index { |m, i| new_moves.push(m) if m && i < MAX_MOVES }
    # Add some original moves (skipping ones in the same slot as a Shadow Move)
    num_original_moves = (relearn_all_moves) ? 3 : [3, 3, 2, 1, 1, 0][self.heartStage]
    if num_original_moves > 0
      relearned_count = 0
      @shadowmoves.each_with_index do |m, i|
        next if !m || i < MAX_MOVES + @shadowmovenum
        new_moves.push(m)
        relearned_count += 1
        break if relearned_count >= num_original_moves
      end
    end
    # Relearn Shadow moves plus some original moves (may not change anything)
    pbReplaceMoves(self, new_moves)
  end

  alias :__shadow_clone :clone
  def clone
    ret = __shadow_clone
    ret.savedev     = self.savedev.clone if self.savedev
    ret.shadowmoves = self.shadowmoves.clone if self.shadowmoves
    return ret
  end
end



#===============================================================================
# Shadow Pokémon in battle.
#===============================================================================
class PokeBattle_Battle
  alias __shadow__pbCanUseItemOnPokemon? pbCanUseItemOnPokemon?

  def pbCanUseItemOnPokemon?(item,pkmn,battler,scene,showMessages=true)
    ret = __shadow__pbCanUseItemOnPokemon?(item,pkmn,battler,scene,showMessages)
    if ret && pkmn.hypermode && ![:JOYSCENT, :EXCITESCENT, :VIVIDSCENT].include?(item)
      scene.pbDisplay(_INTL("This item can't be used on that Pokémon."))
      return false
    end
    return ret
  end
end



class PokeBattle_Battler
  alias __shadow__pbInitPokemon pbInitPokemon

  def pbInitPokemon(*arg)
    if self.pokemonIndex>0 && inHyperMode?
      # Called out of Hyper Mode
      self.pokemon.hypermode = false
      self.pokemon.adjustHeart(-50)
    end
    __shadow__pbInitPokemon(*arg)
    # Called into battle
    if shadowPokemon?
      if GameData::Type.exists?(:SHADOW)
        self.type1 = :SHADOW
        self.type2 = :SHADOW
      end
      self.pokemon.adjustHeart(-30) if pbOwnedByPlayer?
    end
  end

  def shadowPokemon?
    p = self.pokemon
    return p && p.respond_to?("shadowPokemon?") && p.shadowPokemon?
  end
  alias isShadow? shadowPokemon?

  def inHyperMode?
    return false if fainted?
    p = self.pokemon
    return p && p.respond_to?("hypermode") && p.hypermode
  end

  def pbHyperMode
    return if fainted? || !shadowPokemon? || inHyperMode?
    p = self.pokemon
    if @battle.pbRandom(p.heartgauge)<=Pokemon::HEARTGAUGESIZE/4
      p.hypermode = true
      @battle.pbDisplay(_INTL("{1}'s emotions rose to a fever pitch!\nIt entered Hyper Mode!",self.pbThis))
    end
  end

  def pbHyperModeObedience(move)
    return true if !inHyperMode?
    return true if !move || move.type == :SHADOW
    return rand(100)<20
  end
end



#===============================================================================
# Shadow item effects.
#===============================================================================
def pbRaiseHappinessAndReduceHeart(pokemon,scene,amount)
  if !pokemon.shadowPokemon?
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false
  end
  if pokemon.happiness==255 && pokemon.heartgauge==0
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false
  elsif pokemon.happiness==255
    pokemon.adjustHeart(-amount)
    scene.pbDisplay(_INTL("{1} adores you!\nThe door to its heart opened a little.",pokemon.name))
    pbReadyToPurify(pokemon)
    return true
  elsif pokemon.heartgauge==0
    pokemon.changeHappiness("vitamin")
    scene.pbDisplay(_INTL("{1} turned friendly.",pokemon.name))
    return true
  else
    pokemon.changeHappiness("vitamin")
    pokemon.adjustHeart(-amount)
    scene.pbDisplay(_INTL("{1} turned friendly.\nThe door to its heart opened a little.",pokemon.name))
    pbReadyToPurify(pokemon)
    return true
  end
end

ItemHandlers::UseOnPokemon.add(:JOYSCENT,proc { |item,pokemon,scene|
  pbRaiseHappinessAndReduceHeart(pokemon,scene,500)
})

ItemHandlers::UseOnPokemon.add(:EXCITESCENT,proc { |item,pokemon,scene|
  pbRaiseHappinessAndReduceHeart(pokemon,scene,1000)
})

ItemHandlers::UseOnPokemon.add(:VIVIDSCENT,proc { |item,pokemon,scene|
  pbRaiseHappinessAndReduceHeart(pokemon,scene,2000)
})

ItemHandlers::UseOnPokemon.add(:TIMEFLUTE,proc { |item,pokemon,scene|
  if !pokemon.shadowPokemon?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
  pokemon.heartgauge = 0
  pbReadyToPurify(pokemon)
  next true
})

ItemHandlers::CanUseInBattle.add(:JOYSCENT,proc { |item,pokemon,battler,move,firstAction,battle,scene,showMessages|
  if !battler || !battler.shadowPokemon? || !battler.inHyperMode?
    scene.pbDisplay(_INTL("It won't have any effect.")) if showMessages
    next false
  end
  next true
})

ItemHandlers::CanUseInBattle.copy(:JOYSCENT,:EXCITESCENT,:VIVIDSCENT)

ItemHandlers::BattleUseOnBattler.add(:JOYSCENT,proc { |item,battler,scene|
  battler.pokemon.hypermode = false
  battler.pokemon.adjustHeart(-500)
  scene.pbDisplay(_INTL("{1} came to its senses from the {2}!",battler.pbThis,GameData::Item.get(item).name))
  next true
})

ItemHandlers::BattleUseOnBattler.add(:EXCITESCENT,proc { |item,battler,scene|
  battler.pokemon.hypermode = false
  battler.pokemon.adjustHeart(-1000)
  scene.pbDisplay(_INTL("{1} came to its senses from the {2}!",battler.pbThis,GameData::Item.get(item).name))
  next true
})

ItemHandlers::BattleUseOnBattler.add(:VIVIDSCENT,proc { |item,battler,scene|
  battler.pokemon.hypermode = false
  battler.pokemon.adjustHeart(-2000)
  scene.pbDisplay(_INTL("{1} came to its senses from the {2}!",battler.pbThis,GameData::Item.get(item).name))
  next true
})



#===============================================================================
# No additional effect. (Shadow Blast, Shadow Blitz, Shadow Break, Shadow Rave,
# Shadow Rush, Shadow Wave)
#===============================================================================
class PokeBattle_Move_126 < PokeBattle_Move_000
end



#===============================================================================
# Paralyzes the target. (Shadow Bolt)
#===============================================================================
class PokeBattle_Move_127 < PokeBattle_Move_007
end



#===============================================================================
# Burns the target. (Shadow Fire)
#===============================================================================
class PokeBattle_Move_128 < PokeBattle_Move_00A
end



#===============================================================================
# Freezes the target. (Shadow Chill)
#===============================================================================
class PokeBattle_Move_129 < PokeBattle_Move_00C
end



#===============================================================================
# Confuses the target. (Shadow Panic)
#===============================================================================
class PokeBattle_Move_12A < PokeBattle_Move_013
end



#===============================================================================
# Decreases the target's Defense by 2 stages. (Shadow Down)
#===============================================================================
class PokeBattle_Move_12B < PokeBattle_Move_04C
end



#===============================================================================
# Decreases the target's evasion by 2 stages. (Shadow Mist)
#===============================================================================
class PokeBattle_Move_12C < PokeBattle_TargetStatDownMove
  def initialize(battle,move)
    super
    @statDown = [PBStats::EVASION,2]
  end
end



#===============================================================================
# Power is doubled if the target is using Dive. (Shadow Storm)
#===============================================================================
class PokeBattle_Move_12D < PokeBattle_Move_075
end



#===============================================================================
# Two turn attack. On first turn, halves the HP of all active Pokémon.
# Skips second turn (if successful). (Shadow Half)
#===============================================================================
class PokeBattle_Move_12E < PokeBattle_Move
  def pbMoveFailed?(user,targets)
    failed = true
    @battle.eachBattler do |b|
      next if b.hp==1
      failed = false
      break
    end
    if failed
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    @battle.eachBattler do |b|
      next if b.hp==1
      b.pbReduceHP(i.hp/2,false)
    end
    @battle.pbDisplay(_INTL("Each Pokémon's HP was halved!"))
    @battle.eachBattler { |b| b.pbItemHPHealCheck }
    user.effects[PBEffects::HyperBeam] = 2
    user.currentMove = @id
  end
end



#===============================================================================
# Target can no longer switch out or flee, as long as the user remains active.
# (Shadow Hold)
#===============================================================================
class PokeBattle_Move_12F < PokeBattle_Move_0EF
end



#===============================================================================
# User takes recoil damage equal to 1/2 of its current HP. (Shadow End)
#===============================================================================
class PokeBattle_Move_130 < PokeBattle_RecoilMove
  def pbRecoilDamage(user,target)
    return (target.damageState.totalHPLost/2.0).round
  end

  def pbEffectAfterAllHits(user,target)
    return if user.fainted? || target.damageState.unaffected
    # NOTE: This move's recoil is not prevented by Rock Head/Magic Guard.
    amt = pbRecoilDamage(user,target)
    amt = 1 if amt<1
    user.pbReduceHP(amt,false)
    @battle.pbDisplay(_INTL("{1} is damaged by recoil!",user.pbThis))
    user.pbItemHPHealCheck
  end
end



#===============================================================================
# Starts shadow weather. (Shadow Sky)
#===============================================================================
class PokeBattle_Move_131 < PokeBattle_WeatherMove
  def initialize(battle,move)
    super
    @weatherType = PBWeather::ShadowSky
  end
end



#===============================================================================
# Ends the effects of Light Screen, Reflect and Safeguard on both sides.
# (Shadow Shed)
#===============================================================================
class PokeBattle_Move_132 < PokeBattle_Move
  def pbEffectGeneral(user)
    for i in @battle.sides
      i.effects[PBEffects::AuroraVeil]  = 0
      i.effects[PBEffects::Reflect]     = 0
      i.effects[PBEffects::LightScreen] = 0
      i.effects[PBEffects::Safeguard]   = 0
    end
    @battle.pbDisplay(_INTL("It broke all barriers!"))
  end
end



#===============================================================================
#
#===============================================================================
class PokemonTemp
  attr_accessor :heartgauges
end



Events.onStartBattle += proc { |_sender|
  # Record current heart gauges of Pokémon in party, to see if they drop to zero
  # during battle and need to say they're ready to be purified afterwards
  $PokemonTemp.heartgauges = []
  for i in 0...$Trainer.party.length
    $PokemonTemp.heartgauges[i] = $Trainer.party[i].heartgauge
  end
}

Events.onEndBattle += proc { |_sender,_e|
  for i in 0...$PokemonTemp.heartgauges.length
    pokemon = $Trainer.party[i]
    if pokemon && $PokemonTemp.heartgauges[i] &&
       $PokemonTemp.heartgauges[i]!=0 && pokemon.heartgauge==0
      pbReadyToPurify(pokemon)
    end
  end
}

Events.onStepTaken += proc {
  for pkmn in $Trainer.ablePokemonParty
    if pkmn.heartgauge>0
      pkmn.adjustHeart(-1)
      pbReadyToPurify(pkmn) if pkmn.heartgauge==0
    end
  end
  if ($PokemonGlobal.purifyChamber rescue nil)
    $PokemonGlobal.purifyChamber.update
  end
  for i in 0...2
    pkmn = $PokemonGlobal.daycare[i][0]
    next if !pkmn
    pkmn.adjustHeart(-1)
    pkmn.pbUpdateShadowMoves
  end
}
