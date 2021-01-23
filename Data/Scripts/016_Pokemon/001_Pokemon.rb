#===============================================================================
# Instances of this class are individual Pokémon.
# The player's party Pokémon are stored in the array $Trainer.party.
#===============================================================================
class Pokemon
  # @return [Integer] this Pokémon's national Pokédex number
  attr_reader   :species
  # If defined, this Pokémon's form will be this value even if a MultipleForms
  # handler tries to say otherwise.
  # @return [Integer, nil] this Pokémon's form
  attr_accessor :forcedForm
  # If defined, is the time (in Integer form) when this Pokémon's form was set.
  # @return [Integer, nil] the time this Pokémon's form was set
  attr_accessor :formTime
  # @return [Integer] the current experience points
  attr_reader   :exp
  # @return [Integer] the number of steps until this Pokémon hatches, 0 if this Pokémon is not an egg
  attr_accessor :eggsteps
  # @return [Integer] the current HP
  attr_reader   :hp
  # @return [Integer] this Pokémon's current status (from PBStatuses)
  attr_reader   :status
  # @return [Integer] sleep count / toxic flag / 0:
  #   sleep (number of rounds before waking up), toxic (0 = regular poison, 1 = toxic)
  attr_accessor :statusCount
  # This Pokémon's shininess (true, false, nil). Is recalculated if made nil.
  # @param value [Boolean, nil] whether this Pokémon is shiny
  attr_writer   :shiny
  # The index of this Pokémon's ability (0, 1 are natural abilities, 2+ are
  # hidden abilities)as defined for its species/form. An ability may not be
  # defined at this index. Is recalculated (as 0 or 1) if made nil.
  # @param value [Integer, nil] forced ability index (nil if none is set)
  attr_writer   :ability_index
  # If defined, this Pokémon's nature is considered to be this when calculating stats.
  # @param value [Integer, nil] ID of the nature to use for calculating stats
  attr_writer   :nature_for_stats
  # @return [Array<Pokemon::Move>] the moves known by this Pokémon
  attr_accessor :moves
  # @return [Array<Integer>] the IDs of moves known by this Pokémon when it was obtained
  attr_accessor :firstmoves
  # @return [Array<Integer>] an array of ribbons owned by this Pokémon
  attr_accessor :ribbons
  # @return [Integer] contest stats
  attr_accessor :cool, :beauty, :cute, :smart, :tough, :sheen
  # @return [Integer] the Pokérus strain and infection time
  attr_accessor :pokerus
  # @return [Integer] this Pokémon's current happiness (an integer between 0 and 255)
  attr_accessor :happiness
  # @return [Integer] the type of ball used (refer to {$BallTypes} for valid types)
  attr_accessor :ballused
  # @return [Integer] this Pokémon's markings, one bit per marking
  attr_accessor :markings
  # @return [Array<Integer>] an array of IV values for HP, Atk, Def, Speed, Sp. Atk and Sp. Def
  attr_accessor :iv
  # An array of booleans indicating whether a stat is made to have maximum IVs
  # (for Hyper Training). Set like @ivMaxed[PBStats::ATTACK] = true
  # @return [Array<Boolean>] an array of booleans that max each IV value
  attr_accessor :ivMaxed
  # @return [Array<Integer>] this Pokémon's effort values
  attr_accessor :ev
  # @return [Integer] calculated stats
  attr_reader   :totalhp, :attack, :defense, :spatk, :spdef, :speed
  # @return [Owner] this Pokémon's owner
  attr_reader   :owner
  # @return [Integer] the manner this Pokémon was obtained:
  #   0 (met), 1 (as egg), 2 (traded), 4 (fateful encounter)
  attr_accessor :obtain_method
  # @return [Integer] the ID of the map this Pokémon was obtained in
  attr_accessor :obtainMap
  # Describes the manner this Pokémon was obtained. If left undefined,
  # the obtain map's name is used.
  # @return [String] the obtain text
  attr_accessor :obtainText
  # @return [Integer] the level of this Pokémon when it was obtained
  attr_accessor :obtainLevel
  # If this Pokémon hatched from an egg, returns the map ID where the hatching happened.
  # Otherwise returns 0.
  # @return [Integer] the map ID where egg was hatched (0 by default)
  attr_accessor :hatchedMap
  # Another Pokémon which has been fused with this Pokémon (or nil if there is none).
  # Currently only used by Kyurem, to record a fused Reshiram or Zekrom.
  # @return [Pokemon, nil] the Pokémon fused into this one (nil if there is none)
  attr_accessor :fused
  # @return [Integer] this Pokémon's personal ID
  attr_accessor :personalID

  # Max total IVs
  IV_STAT_LIMIT = 31
  # Max total EVs
  EV_LIMIT      = 510
  # Max EVs that a single stat can have
  EV_STAT_LIMIT = 252
  # Maximum length a Pokémon's nickname can be
  MAX_NAME_SIZE = 10
  # Maximum number of moves a Pokémon can know at once
  MAX_MOVES     = 4

  def species_data
    return GameData::Species.get_species_form(@species, formSimple)
  end

  #=============================================================================
  # Species and form
  #=============================================================================

  # Changes the Pokémon's species and re-calculates its statistics.
  # @param species_id [Integer] id of the species to change this Pokémon to
  def species=(species_id)
    new_species_data = GameData::Species.get(species_id)
    return if @species == new_species_data.species
    @species    = new_species_data.species
    @form       = new_species_data.form if new_species_data.form != 0
    @forcedForm = nil
    @level      = nil   # In case growth rate is different for the new species
    @ability    = nil
    calcStats
  end

  # @param check_species [Integer, Symbol, String] id of the species to check for
  # @return [Boolean] whether this Pokémon is of the specified species
  def isSpecies?(check_species)
    return @species == check_species || (GameData::Species.exists?(check_species) &&
                                        @species == GameData::Species.get(check_species).species)
  end

  def form
    return @forcedForm if !@forcedForm.nil?
    return @form if $game_temp.in_battle
    calc_form = MultipleForms.call("getForm", self)
    self.form = calc_form if calc_form != nil && calc_form != @form
    return @form
  end

  def formSimple
    return @forcedForm || @form
  end

  def form=(value)
    oldForm = @form
    @form = value
    @ability = nil
    yield if block_given?
    MultipleForms.call("onSetForm", self, value, oldForm)
    calcStats
    pbSeenForm(self)
  end

  def setForm(value)
    self.form = value
  end

  def formSimple=(value)
    @form = value
    calcStats
  end

  #=============================================================================
  # Level
  #=============================================================================

  # @return [Integer] this Pokémon's level
  def level
    @level = PBExperience.pbGetLevelFromExperience(@exp, growth_rate) if !@level
    return @level
  end

  # Sets this Pokémon's level. The given level must be between 1 and the
  # maximum level (defined in {PBExperience}).
  # @param value [Integer] new level (between 1 and the maximum level)
  def level=(value)
    if value < 1 || value > PBExperience.maxLevel
      raise ArgumentError.new(_INTL("The level number ({1}) is invalid.", value))
    end
    @exp = PBExperience.pbGetStartExperience(value, growth_rate)
    @level = value
  end

  # Sets this Pokémon's Exp. Points.
  # @param value [Integer] new experience points
  def exp=(value)
    @exp = value
    @level = nil
  end

  # @return [Boolean] whether this Pokémon is an egg
  def egg?
    return @eggsteps > 0
  end
  alias isEgg? egg?

  # @return [Integer] this Pokémon's growth rate (from PBGrowthRates)
  def growth_rate
    return species_data.growth_rate
  end

  # @return [Integer] this Pokémon's base Experience value
  def base_exp
    return species_data.base_exp
  end

  # @return [Float] a number between 0 and 1 indicating how much of the current level's
  #   Exp this Pokémon has
  def expFraction
    lvl = self.level
    return 0.0 if lvl >= PBExperience.maxLevel
    g_rate = growth_rate
    start_exp = PBExperience.pbGetStartExperience(lvl, g_rate)
    end_exp   = PBExperience.pbGetStartExperience(lvl + 1, g_rate)
    return (@exp - start_exp).to_f / (end_exp - start_exp)
  end

  #=============================================================================
  # Status
  #=============================================================================

  # Sets the Pokémon's health.
  # @param value [Integer] new HP value
  def hp=(value)
    @hp = value.clamp(0, @totalhp)
    healStatus if @hp == 0
  end

  # Sets this Pokémon's status. See {PBStatuses} for all possible status effects.
  # @param value [Integer, Symbol, String] status to set (from {PBStatuses})
  def status=(value)
    new_status = getID(PBStatuses, value)
    if !new_status
      raise ArgumentError, _INTL('Attempted to set {1} as Pokémon status', value.class.name)
    end
    @status = new_status
  end

  # @return [Boolean] whether the Pokémon is not fainted and not an egg
  def able?
    return !egg? && @hp > 0
  end
  alias isAble? able?

  # @return [Boolean] whether the Pokémon is fainted
  def fainted?
    return !egg? && @hp <= 0
  end
  alias isFainted? fainted?

  # Heals all HP of this Pokémon.
  def healHP
    return if egg?
    @hp = @totalhp
  end

  # Heals the status problem of this Pokémon.
  def healStatus
    return if egg?
    @status      = PBStatuses::NONE
    @statusCount = 0
  end

  # Restores all PP of this Pokémon. If a move index is given, restores the PP
  # of the move in that index.
  # @param move_index [Integer] index of the move to heal (-1 if all moves
  #   should be healed)
  def healPP(move_index = -1)
    return if egg?
    if move_index >= 0
      @moves[move_index].pp = @moves[move_index].total_pp
    else
      @moves.each { |m| m.pp = m.total_pp }
    end
  end

  # Heals all HP, PP, and status problems of this Pokémon.
  def heal
    return if egg?
    healHP
    healStatus
    healPP
  end

  #=============================================================================
  # Types
  #=============================================================================

  # @return [Integer] this Pokémon's first type
  def type1
    return species_data.type1
  end

  # @return [Integer] this Pokémon's second type, or the first type if none is defined
  def type2
    sp_data = species_data
    return sp_data.type2 || sp_data.type1
  end

  # @return [Array<Integer>] an array of this Pokémon's types
  def types
    sp_data = species_data
    ret = [sp_data.type1]
    ret.push(sp_data.type2) if sp_data.type2 && sp_data.type2 != sp_data.type1
    return ret
  end

  # @param type [Integer, Symbol, String] type to check
  # @return [Boolean] whether this Pokémon has the specified type
  def hasType?(type)
    type = GameData::Type.get(type).id
    return self.types.include?(type)
  end

  #=============================================================================
  # Gender
  #=============================================================================

  # @return [0, 1, 2] this Pokémon's gender (0 = male, 1 = female, 2 = genderless)
  def gender
    if !@gender
      gender_rate = species_data.gender_rate
      case gender_rate
      when PBGenderRates::AlwaysMale   then @gender = 0
      when PBGenderRates::AlwaysFemale then @gender = 1
      when PBGenderRates::Genderless   then @gender = 2
      else
        @gender = ((@personalID & 0xFF) < PBGenderRates.genderByte(gender_rate)) ? 1 : 0
      end
    end
    return @gender
  end

  # Sets this Pokémon's gender to a particular gender (if possible).
  # @param value [0, 1] new gender (0 = male, 1 = female)
  def gender=(value)
    return if singleGendered?
    @gender = value if value.nil? || value == 0 || value == 1
  end

  # Makes this Pokémon male.
  def makeMale; self.gender = 0; end

  # Makes this Pokémon female.
  def makeFemale; self.gender = 1; end

  # @return [Boolean] whether this Pokémon is male
  def male?; return self.gender == 0; end
  alias isMale? male?

  # @return [Boolean] whether this Pokémon is female
  def female?; return self.gender == 1; end
  alias isFemale? female?

  # @return [Boolean] whether this Pokémon is genderless
  def genderless?; return self.gender == 2; end
  alias isGenderless? genderless?

  # @return [Boolean] whether this Pokémon species is restricted to only ever being one
  #   gender (or genderless)
  def singleGendered?
    gender_rate = species_data.gender_rate
    return [PBGenderRates::AlwaysMale, PBGenderRates::AlwaysFemale,
            PBGenderRates::Genderless].include?(gender_rate)
  end
  alias isSingleGendered? singleGendered?

  #=============================================================================
  # Shininess
  #=============================================================================

  # @return [Boolean] whether this Pokémon is shiny (differently colored)
  def shiny?
    if @shiny.nil?
      a = @personalID ^ @owner.id
      b = a & 0xFFFF
      c = (a >> 16) & 0xFFFF
      d = b ^ c
      @shiny = d < SHINY_POKEMON_CHANCE
    end
    return @shiny
  end
  alias isShiny? shiny?

  #=============================================================================
  # Ability
  #=============================================================================

  # @return [Integer] the index of this Pokémon's ability
  def ability_index
    @ability_index = (@personalID & 1) if !@ability_index
    return @ability_index
  end

  # @return [GameData::Ability, nil] an Ability object corresponding to this Pokémon's ability
  def ability
    return GameData::Ability.try_get(ability_id)
  end

  # @return [Symbol, nil] the ability symbol of this Pokémon's ability
  def ability_id
    if !@ability
      sp_data = species_data
      abil_index = ability_index
      if abil_index >= 2   # Hidden ability
        @ability = sp_data.hidden_abilities[abil_index - 2]
        abil_index = (@personalID & 1) if !@ability
      end
      if !@ability   # Natural ability or no hidden ability defined
        @ability = sp_data.abilities[abil_index] || sp_data.abilities[0]
      end
    end
    return @ability
  end

  def ability=(value)
    return if value && !GameData::Ability.exists?(value)
    @ability = (value) ? GameData::Ability.get(value).id : value
  end

  # Returns whether this Pokémon has a particular ability. If no value
  # is given, returns whether this Pokémon has an ability set.
  # @param check_ability [Symbol, GameData::Ability, Integer] ability ID to check
  # @return [Boolean] whether this Pokémon has a particular ability or
  #   an ability at all
  def hasAbility?(check_ability = nil)
    current_ability = self.ability
    return !current_ability.nil? if check_ability.nil?
    return current_ability == check_ability
  end

  # @return [Boolean] whether this Pokémon has a hidden ability
  def hasHiddenAbility?
    return ability_index >= 2
  end

  # @return [Array<Array<Symbol,Integer>>] the abilities this Pokémon can have,
  #   where every element is [ability ID, ability index]
  def getAbilityList
    ret = []
    sp_data = species_data
    sp_data.abilities.each_with_index { |a, i| ret.push([a, i]) if a }
    sp_data.hidden_abilities.each_with_index { |a, i| ret.push([a, i + 2]) if a }
    return ret
  end

  #=============================================================================
  # Nature
  #=============================================================================

  # @return [Integer] the ID of this Pokémon's nature
  def nature
    @nature = (@personalID % 25) if !@nature
    return @nature
  end

  # Returns the calculated nature, taking into account things that change its
  # stat-altering effect (i.e. Gen 8 mints). Only used for calculating stats.
  # @return [Integer] this Pokémon's calculated nature
  def nature_for_stats
    return @nature_for_stats || self.nature
  end

  # Sets this Pokémon's nature to a particular nature.
  # @param value [Integer, String, Symbol] nature to change to
  def nature=(value)
    @nature = getID(PBNatures, value)
    calcStats if !@nature_for_stats
  end

  # Returns whether this Pokémon has a particular nature. If no value is given,
  # returns whether this Pokémon has a nature set.
  # @param nature [Integer] nature ID to check
  # @return [Boolean] whether this Pokémon has a particular nature or a nature
  #   at all
  def hasNature?(check_nature = -1)
    current_nature = self.nature
    return current_nature >= 0 if check_nature < 0
    return current_nature == getID(PBNatures, check_nature)
  end

  #=============================================================================
  # Items
  #=============================================================================

  # @return [GameData::Item, nil] an Item object corresponding to this Pokémon's item
  def item
    return GameData::Item.try_get(@item)
  end

  def item_id
    return @item
  end

  # Gives an item to this Pokémon to hold.
  # @param value [Symbol, GameData::Item, Integer, nil] ID of the item to give
  #   to this Pokémon
  def item=(value)
    return if value && !GameData::Item.exists?(value)
    @item = (value) ? GameData::Item.get(value).id : value
  end

  # Returns whether this Pokémon is holding an item. If an item id is passed,
  # returns whether the Pokémon is holding that item.
  # @param check_item [Symbol, GameData::Item, Integer] item ID to check
  # @return [Boolean] whether the Pokémon is holding the specified item or
  #   an item at all
  def hasItem?(check_item = nil)
    return !@item.nil? if check_item.nil?
    return self.item == check_item
  end

  # @return [Array<Integer>] the items this species can be found holding in the wild
  def wildHoldItems
    sp_data = species_data
    return [sp_data.wild_item_common, sp_data.wild_item_uncommon, sp_data.wild_item_rare]
  end

  # @return [Mail, nil] mail held by this Pokémon (nil if there is none)
  def mail
    @mail = nil if @mail && (!@mail.item || !hasItem?(@mail.item))
    return @mail
  end

  # If mail is a Mail object, gives that mail to this Pokémon. If nil is given,
  # removes the held mail.
  # @param mail [Mail, nil] mail to be held by this Pokémon
  def mail=(mail)
    if !mail.nil? && !mail.is_a?(Mail)
      raise ArgumentError, _INTL('Invalid value {1} given', mail.inspect)
    end
    @mail = mail
  end

  #=============================================================================
  # Moves
  #=============================================================================

  # @return [Integer] the number of moves known by the Pokémon
  def numMoves
    return @moves.length
  end

  # @param move_id [Integer, Symbol, String] ID of the move to check
  # @return [Boolean] whether the Pokémon knows the given move
  def hasMove?(move_id)
    move_data = GameData::Move.try_get(move_id)
    return false if !move_data
    return @moves.any? { |m| m.id == move_data.id }
  end
  alias knowsMove? hasMove?

  # Returns the list of moves this Pokémon can learn by levelling up.
  # @return [Array<Array<Integer,Symbol>>] this Pokémon's move list, where every element is [level, move ID]
  def getMoveList
    return species_data.moves
  end

  # Sets this Pokémon's movelist to the default movelist it originally had.
  def resetMoves
    this_level = self.level
    # Find all level-up moves that self could have learned
    moveset = self.getMoveList
    knowable_moves = []
    moveset.each { |m| knowable_moves.push(m[1]) if m[0] <= this_level }
    # Remove duplicates (retaining the latest copy of each move)
    knowable_moves = knowable_moves.reverse
    knowable_moves |= []
    knowable_moves = knowable_moves.reverse
    # Add all moves
    @moves.clear
    first_move_index = knowable_moves.length - MAX_MOVES
    first_move_index = 0 if first_move_index < 0
    for i in first_move_index...knowable_moves.length
      @moves.push(Pokemon::Move.new(knowable_moves[i]))
    end
  end

  # Silently learns the given move. Will erase the first known move if it has to.
  # @param move_id [Integer, Symbol, String] ID of the move to learn
  def pbLearnMove(move_id)
    move_data = GameData::Move.try_get(move_id)
    return if !move_data
    # Check if self already knows the move; if so, move it to the end of the array
    @moves.each_with_index do |m, i|
      next if m.id != move_data.id
      @moves.push(m)
      @moves.delete_at(i)
      return
    end
    # Move is not already known; learn it
    @moves.push(Pokemon::Move.new(move_data.id))
    # Delete the first known move if self now knows more moves than it should
    @moves.shift if numMoves > MAX_MOVES
  end

  # Deletes the given move from the Pokémon.
  # @param move_id [Integer, Symbol, String] ID of the move to delete
  def pbDeleteMove(move_id)
    move_data = GameData::Move.try_get(move_id)
    return if !move_data
    @moves.delete_if { |m| m.id == move_data.id }
  end

  # Deletes the move at the given index from the Pokémon.
  # @param index [Integer] index of the move to be deleted
  def pbDeleteMoveAtIndex(index)
    @moves.delete_at(index)
  end

  # Deletes all moves from the Pokémon.
  def pbDeleteAllMoves
    @moves.clear
  end

  # Copies currently known moves into a separate array, for Move Relearner.
  def pbRecordFirstMoves
    pbClearFirstMoves
    @moves.each { |m| @firstmoves.push(m.id) }
  end

  # Adds a move to this Pokémon's first moves.
  # @param move_id [Integer, Symbol, String] ID of the move to add
  def pbAddFirstMove(move_id)
    move_data = GameData::Move.try_get(move_id)
    @firstmoves.push(move_data.id) if move_data && !@firstmoves.include?(move_data.id)
  end

  # Removes a move from this Pokémon's first moves.
  # @param move_id [Integer, Symbol, String] ID of the move to remove
  def pbRemoveFirstMove(move_id)
    move_data = GameData::Move.try_get(move_id)
    @firstmoves.delete(move_data.id) if move_data
  end

  # Clears this Pokémon's first moves.
  def pbClearFirstMoves
    @firstmoves.clear
  end

  # @param move_id [Integer, Symbol, String] ID of the move to check
  # @return [Boolean] whether the Pokémon is compatible with the given move
  def compatibleWithMove?(move_id)
    move_data = GameData::Move.try_get(move_id)
    return move_data && species_data.tutor_moves.include?(move_data.id)
  end

  #=============================================================================
  # Ribbons
  #=============================================================================

  # @return [Integer] the number of ribbons this Pokémon has
  def ribbonCount
    return @ribbons.length
  end

  # @param ribbon [Integer, Symbol, String] ribbon ID to check
  # @return [Boolean] whether this Pokémon has the specified ribbon
  def hasRibbon?(ribbon)
    ribbon = getID(PBRibbons, ribbon)
    return ribbon > 0 && @ribbons.include?(ribbon)
  end

  # Gives a ribbon to this Pokémon.
  # @param ribbon [Integer, Symbol, String] ID of the ribbon to give
  def giveRibbon(ribbon)
    ribbon = getID(PBRibbons, ribbon)
    return if ribbon == 0
    @ribbons.push(ribbon) if !@ribbons.include?(ribbon)
  end

  # Replaces one ribbon with the next one along, if possible.
  def upgradeRibbon(*arg)
    for i in 0...arg.length - 1
      for j in 0...@ribbons.length
        next if @ribbons[j] != getID(PBRibbons, arg[i])
        @ribbons[j] = getID(PBRibbons, arg[i + 1])
        return @ribbons[j]
      end
    end
    if !hasRibbon?(arg[arg.length - 1])
      first_ribbon = getID(PBRibbons, arg[0])
      giveRibbon(first_ribbon)
      return first_ribbon
    end
    return 0
  end

  # Removes the specified ribbon from this Pokémon.
  # @param ribbon [Integer, Symbol, String] id of the ribbon to remove
  def takeRibbon(ribbon)
    return if !@ribbons
    ribbon = getID(PBRibbons, ribbon)
    return if ribbon == 0
    for i in 0...@ribbons.length
      next if @ribbons[i] != ribbon
      @ribbons[i] = nil
      break
    end
    @ribbons.compact!
  end

  # Removes all ribbons from this Pokémon.
  def clearAllRibbons
    @ribbons.clear
  end

  #=============================================================================
  # Pokérus
  #=============================================================================

  # @return [Integer] the Pokérus infection stage for this Pokémon
  def pokerusStrain
    return @pokerus / 16
  end

  # Returns the Pokérus infection stage for this Pokémon. The possible stages are
  # 0 (not infected), 1 (infected) and 2 (cured)
  # @return [0, 1, 2] current Pokérus infection stage
  def pokerusStage
    return 0 if @pokerus == 0
    return ((@pokerus % 16) == 0) ? 2 : 1
  end

  # Gives this Pokémon Pokérus (either the specified strain or a random one).
  # @param strain [Integer] Pokérus strain to give
  def givePokerus(strain = 0)
    return if self.pokerusStage == 2   # Can't re-infect a cured Pokémon
    strain = rand(1, 16) if strain <= 0 || strain >= 16
    time = 1 + (strain % 4)
    @pokerus = time
    @pokerus |= strain << 4
  end

  # Resets the infection time for this Pokémon's Pokérus (even if cured).
  def resetPokerusTime
    return if @pokerus == 0
    strain = @pokerus % 16
    time = 1 + (strain % 4)
    @pokerus = time
    @pokerus |= strain << 4
  end

  # Reduces the time remaining for this Pokémon's Pokérus (if infected).
  def lowerPokerusCount
    return if self.pokerusStage != 1
    @pokerus -= 1
  end

  #=============================================================================
  # Ownership, obtained information
  #=============================================================================

  # Changes this Pokémon's owner.
  # @param new_owner [Owner] the owner to change to
  def owner=(new_owner)
    validate new_owner => Owner
    @owner = new_owner
  end

  # @param trainer [PokeBattle_Trainer] the trainer to compare to the original trainer
  # @return [Boolean] whether the given trainer is not this Pokémon's original trainer
  def foreign?(trainer)
    return @owner.id != trainer.id || @owner.name != trainer.name
  end
  alias isForeign? foreign?

  # @return [Time] the time when this Pokémon was obtained
  def timeReceived
    return Time.at(@timeReceived)
  end

  # Sets the time when this Pokémon was obtained.
  # @param value [Integer, Time, #to_i] time in seconds since Unix epoch
  def timeReceived=(value)
    @timeReceived = value.to_i
  end

  # @return [Time] the time when this Pokémon hatched
  def timeEggHatched
    return (obtain_method == 1) ? Time.at(@timeEggHatched) : nil
  end

  # Sets the time when this Pokémon hatched.
  # @param value [Integer, Time, #to_i] time in seconds since Unix epoch
  def timeEggHatched=(value)
    @timeEggHatched = value.to_i
  end

  #=============================================================================
  # Other
  #=============================================================================

  # @return [String] the name of this Pokémon
  def name
    return (nicknamed?) ? @name || speciesName
  end

  # @param value [String] the nickname of this Pokémon
  def name=(value)
    value = nil if !value || value.empty? || value == speciesName
    @name = value
  end

  # @return [Boolean] whether this Pokémon has been nicknamed
  def nicknamed?
    return @name && !@name.empty?
  end

  # @return [String] the species name of this Pokémon
  def speciesName
    return species_data.name
  end

  # @return [String] a string stating the Unown form of this Pokémon
  def unownShape
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZ?!"[@form, 1]
  end

  # @return [Integer] the height of this Pokémon in decimetres (0.1 metres)
  def height
    return species_data.height
  end

  # @return [Integer] the weight of this Pokémon in hectograms (0.1 kilograms)
  def weight
    return species_data.weight
  end

  # @return [Array<Integer>] the EV yield of this Pokémon (an array of six values)
  def evYield
    return species_data.evs.clone
  end

  # Changes the happiness of this Pokémon depending on what happened to change it.
  # @param method [String] the happiness changing method (e.g. 'walking')
  def changeHappiness(method)
    gain = 0
    happiness_range = @happiness / 100
    case method
    when "walking"
      gain = [2, 2, 1][happiness_range]
    when "levelup"
      gain = [5, 4, 3][happiness_range]
    when "groom"
      gain = [10, 10, 4][happiness_range]
    when "evberry"
      gain = [10, 5, 2][happiness_range]
    when "vitamin"
      gain = [5, 3, 2][happiness_range]
    when "wing"
      gain = [3, 2, 1][happiness_range]
    when "machine", "battleitem"
      gain = [1, 1, 0][happiness_range]
    when "faint"
      gain = -1
    when "faintbad"   # Fainted against an opponent that is 30+ levels higher
      gain = [-5, -5, -10][happiness_range]
    when "powder"
      gain = [-5, -5, -10][happiness_range]
    when "energyroot"
      gain = [-10, -10, -15][happiness_range]
    when "revivalherb"
      gain = [-15, -15, -20][happiness_range]
    else
      raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
    if gain > 0
      gain += 1 if @obtainMap == $game_map.map_id
      gain += 1 if @ballused == pbGetBallType(:LUXURYBALL)
      gain = (gain * 1.5).floor if hasItem?(:SOOTHEBELL)
    end
    @happiness = (@happiness + gain).clamp(0, 255)
  end

  #=============================================================================
  # Stat calculations
  #=============================================================================

  # @return [Array<Integer>] this Pokémon's base stats, an array of six values
  def baseStats
    return species_data.base_stats.clone
  end

  # Returns this Pokémon's effective IVs, taking into account Hyper Training.
  # Only used for calculating stats.
  # @return [Array<Boolean>] array containing this Pokémon's effective IVs
  def calcIV
    ret = self.iv.clone
    PBStats.eachStat { |s| ret[s] = IV_STAT_LIMIT if @ivMaxed[s] }
    return ret
  end

  # @return [Integer] the maximum HP of this Pokémon
  def calcHP(base, level, iv, ev)
    return 1 if base == 1   # For Shedinja
    return ((base * 2 + iv + (ev / 4)) * level / 100).floor + level + 10
  end

  # @return [Integer] the specified stat of this Pokémon (not used for total HP)
  def calcStat(base, level, iv, ev, nat)
    return ((((base * 2 + iv + (ev / 4)) * level / 100).floor + 5) * nat / 100).floor
  end

  # Recalculates this Pokémon's stats.
  def calcStats
    base_stats = self.baseStats
    this_level = self.level
    this_IV    = self.calcIV
    nature_mod = PBNatures.getStatChanges(self.nature_for_stats)
    stats = []
    PBStats.eachStat do |s|
      if s == PBStats::HP
        stats[s] = calcHP(base_stats[s], this_level, this_IV[s], @ev[s])
      else
        stats[s] = calcStat(base_stats[s], this_level, this_IV[s], @ev[s], nature_mod[s])
      end
    end
    hpDiff = @totalhp - @hp
    @totalhp = stats[PBStats::HP]
    @hp      = @totalhp - hpDiff
    @attack  = stats[PBStats::ATTACK]
    @defense = stats[PBStats::DEFENSE]
    @spatk   = stats[PBStats::SPATK]
    @spdef   = stats[PBStats::SPDEF]
    @speed   = stats[PBStats::SPEED]
  end

  #=============================================================================
  # Pokémon creation
  #=============================================================================

  # Creates a copy of this Pokémon and returns it.
  # @return [Pokemon] a copy of this Pokémon
  def clone
    ret = super
    ret.iv         = @iv.clone
    ret.ivMaxed    = @ivMaxed.clone
    ret.ev         = @ev.clone
    ret.moves      = []
    @moves.each_with_index { |m, i| ret.moves[i] = m.clone }
    ret.firstmoves = @firstmoves.cline
    ret.owner      = @owner.clone
    ret.ribbons    = @ribbons.clone
    return ret
  end

  # Creates a new Pokémon object.
  # @param species [Symbol, String, Integer] Pokémon species
  # @param level [Integer] Pokémon level
  # @param owner [Owner, PokeBattle_Trainer] Pokémon owner (the player by default)
  # @param withMoves [Boolean] whether the Pokémon should have moves
  def initialize(species, level, owner = $Trainer, withMoves = true)
    species_data = GameData::Species.get(species)
    @species          = species_data.species
    @form             = species_data.form
    @forcedForm       = nil
    @formTime         = nil
    self.level        = level
    @eggsteps         = 0
    healStatus
    @gender           = nil
    @shiny            = nil
    @ability_index    = nil
    @ability          = nil
    @nature           = nil
    @nature_for_stats = nil
    @item             = nil
    @mail             = nil
    @moves            = []
    resetMoves if withMoves
    @firstmoves       = []
    @ribbons          = []
    @cool             = 0
    @beauty           = 0
    @cute             = 0
    @smart            = 0
    @tough            = 0
    @sheen            = 0
    @pokerus          = 0
    @name             = nil
    @happiness        = species_data.happiness
    @ballused         = 0
    @markings         = 0
    @iv               = []
    @ivMaxed          = []
    @ev               = []
    PBStats.eachStat do |s|
      @iv[s]          = rand(IV_STAT_LIMIT + 1)
      @ev[s]          = 0
    end
    if owner.is_a?(Owner)
      @owner = owner
    elsif owner.is_a?(PokeBattle_Trainer)
      @owner = Owner.new_from_trainer(owner)
    else
      @owner = Owner.new(0, '', 2, 2)
    end
    @obtain_method    = 0   # Met
    @obtain_method    = 4 if $game_switches && $game_switches[FATEFUL_ENCOUNTER_SWITCH]
    @obtainMap        = ($game_map) ? $game_map.map_id : 0
    @obtainText       = nil
    @obtainLevel      = level
    @hatchedMap       = 0
    @timeReceived     = pbGetTimeNow.to_i
    @timeEggHatched   = nil
    @fused            = nil
    @personalID       = rand(2 ** 16) | rand(2 ** 16) << 16
    @hp               = 1
    @totalhp          = 1
    calcStats
    if @form == 0
      f = MultipleForms.call("getFormOnCreation", self)
      if f
        self.form = f
        resetMoves if withMoves
      end
    end
  end
end
