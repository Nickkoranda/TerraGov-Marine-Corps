/* Stack type objects!
 * Contains:
 * 		Stacks
 * 		Recipe datum
 * 		Recipe list datum
 */

/*
 * Stacks
 */

/obj/item/stack
	gender = PLURAL
	origin_tech = "materials=1"
	var/list/datum/stack_recipe/recipes
	var/singular_name
	var/amount = 1
	var/max_amount //also see stack recipes initialisation, param "max_res_amount" must be equal to this max_amount
	var/stack_id //used to determine if two stacks are of the same kind.

/obj/item/stack/New(var/loc, var/amount = null)
	..()
	if(amount)
		src.amount = amount


/obj/item/stack/Destroy()
	if (usr && usr.interactee == src)
		usr << browse(null, "window=stack")
	. = ..()

/obj/item/stack/examine(mob/user)
	..()
	to_chat(user, "There are [amount] [singular_name]\s in the stack.")

/obj/item/stack/attack_self(mob/user as mob)
	list_recipes(user)

/obj/item/stack/proc/list_recipes(mob/user as mob, recipes_sublist)
	if(!recipes)
		return
	if(!src || amount <= 0)
		user << browse(null, "window=stack")
	user.set_interaction(src) //for correct work of onclose
	var/list/recipe_list = recipes
	if(recipes_sublist && recipe_list[recipes_sublist] && istype(recipe_list[recipes_sublist], /datum/stack_recipe_list))
		var/datum/stack_recipe_list/srl = recipe_list[recipes_sublist]
		recipe_list = srl.recipes
	var/t1 = text("<HTML><HEAD><title>Constructions from []</title></HEAD><body><TT>Amount Left: []<br>", src, src.amount)
	for(var/i = 1; i <= recipe_list.len, i++)
		var/E = recipe_list[i]
		if(isnull(E))
			t1 += "<hr>"
			continue

		if(i > 1 && !isnull(recipe_list[i-1]))
			t1+="<br>"

		if(istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/srl = E
			if(src.amount >= srl.req_amount)
				t1 += "<a href='?src=\ref[src];sublist=[i]'>[srl.title] ([srl.req_amount] [src.singular_name]\s)</a>"
			else
				t1 += "[srl.title] ([srl.req_amount] [src.singular_name]\s)<br>"

		if(istype(E, /datum/stack_recipe))
			var/datum/stack_recipe/R = E
			var/max_multiplier = round(src.amount / R.req_amount)
			var/title as text
			var/can_build = 1
			can_build = can_build && (max_multiplier > 0)
			if(R.res_amount > 1)
				title += "[R.res_amount]x [R.title]\s"
			else
				title += "[R.title]"
			title+= " ([R.req_amount] [src.singular_name]\s)"
			if(can_build)
				t1 += text("<A href='?src=\ref[src];sublist=[recipes_sublist];make=[i];multiplier=1'>[title]</A>  ")
			else
				t1 += text("[]", title)
				continue
			if(R.max_res_amount>1 && max_multiplier > 1)
				max_multiplier = min(max_multiplier, round(R.max_res_amount/R.res_amount))
				t1 += " |"
				var/list/multipliers = list(5, 10, 25)
				for (var/n in multipliers)
					if (max_multiplier>=n)
						t1 += " <A href='?src=\ref[src];make=[i];multiplier=[n]'>[n*R.res_amount]x</A>"
				if(!(max_multiplier in multipliers))
					t1 += " <A href='?src=\ref[src];make=[i];multiplier=[max_multiplier]'>[max_multiplier*R.res_amount]x</A>"

	t1 += "</TT></body></HTML>"
	user << browse(t1, "window=stack")
	onclose(user, "stack")
	return

/obj/item/stack/Topic(href, href_list)
	..()
	if((usr.is_mob_restrained() || usr.stat || usr.get_active_hand() != src))
		return

	if(href_list["sublist"] && !href_list["make"])
		list_recipes(usr, text2num(href_list["sublist"]))

	if(href_list["make"])
		if(amount < 1) qdel(src) //Never should happen

		var/list/recipes_list = recipes
		if(href_list["sublist"])
			var/datum/stack_recipe_list/srl = recipes_list[text2num(href_list["sublist"])]
			recipes_list = srl.recipes
		var/datum/stack_recipe/R = recipes_list[text2num(href_list["make"])]
		var/multiplier = text2num(href_list["multiplier"])
		if(!multiplier || (multiplier <= 0)) //href exploit protection
			return
		if(amount < R.req_amount * multiplier)
			if(R.req_amount * multiplier > 1)
				to_chat(usr, "<span class='warning'>You need more [name] to build \the [R.req_amount*multiplier] [R.title]\s!</span>")
			else
				to_chat(usr, "<span class='warning'>You need more [name] to build \the [R.title]!</span>")
			return

		if(istype(get_area(usr.loc), /area/sulaco/hangar))  //HANGAR BUILDING
			to_chat(usr, "<span class='warning'>No. This area is needed for the dropships and personnel.</span>")
			return
		//1 is absolute one per tile, 2 is directional one per tile. Hacky way to get around it without adding more vars
		if(R.one_per_turf)
			if(R.one_per_turf == 1 && (locate(R.result_type) in usr.loc))
				to_chat(usr, "<span class='warning'>There is already another [R.title] here!</span>")
				return
			for(var/obj/O in usr.loc) //Objects, we don't care about mobs. Turfs are checked elsewhere
				if(O.density && !istype(O, R.result_type) && !((O.flags_atom & ON_BORDER) && R.one_per_turf == 2)) //Note: If no dense items, or if dense item, both it and result must be border tiles
					to_chat(usr, "<span class='warning'>You need a clear, open area to build \a [R.title]!</span>")
					return
				if(R.one_per_turf == 2 && (O.flags_atom & ON_BORDER) && O.dir == usr.dir) //We check overlapping dir here. Doesn't have to be the same type
					to_chat(usr, "<span class='warning'>There is already \a [O.name] in this direction!</span>")
					return
		if(R.on_floor && istype(usr.loc, /turf/open))
			var/turf/open/OT = usr.loc
			if(!OT.allow_construction)
				to_chat(usr, "<span class='warning'>\The [R.title] must be constructed on a proper surface!</span>")
				return
		if(R.time)
			if(usr.action_busy) return
			if(R.skill_req)
				if(ishuman(usr) && usr.mind && usr.mind.cm_skills && usr.mind.cm_skills.construction < R.skill_req)
					usr.visible_message("<span class='notice'>[usr] fumbles around figuring out how to build with [src].</span>",
					"<span class='notice'>You fumble around figuring out how to build with [src].</span>")
					var/fumbling_time = R.time * ( R.skill_req - usr.mind.cm_skills.construction )
					if(!do_after(usr, fumbling_time, TRUE, 5, BUSY_ICON_BUILD)) return
			usr.visible_message("<span class='notice'>[usr] starts assembling \a [R.title].</span>",
			"<span class='notice'>You start assembling \a [R.title].</span>")
			if(!do_after(usr, R.time, TRUE, 5, BUSY_ICON_BUILD))
				return
		//We want to check this again for girder stacking
		if(R.one_per_turf == 1 && (locate(R.result_type) in usr.loc))
			to_chat(usr, "<span class='warning'>There is already another [R.title] here!</span>")
			return
		for(var/obj/O in usr.loc) //Objects, we don't care about mobs. Turfs are checked elsewhere
			if(O.density && !istype(O, R.result_type) && !((O.flags_atom & ON_BORDER) && R.one_per_turf == 2))
				to_chat(usr, "<span class='warning'>You need a clear, open area to build \a [R.title]!</span>")
				return
			if(R.one_per_turf == 2 && (O.flags_atom & ON_BORDER) && O.dir == usr.dir)
				to_chat(usr, "<span class='warning'>There is already \a [O.name] in this direction!</span>")
				return
		if(amount < R.req_amount * multiplier)
			return
		var/atom/O = new R.result_type(usr.loc)
		usr.visible_message("<span class='notice'>[usr] assembles \a [O].</span>",
		"<span class='notice'>You assemble \a [O].</span>")
		O.dir = usr.dir
		if(R.max_res_amount > 1)
			var/obj/item/stack/new_item = O
			new_item.amount = R.res_amount * multiplier
			//new_item.add_to_stacks(usr)
		amount -= R.req_amount * multiplier
		if(amount <= 0)
			var/oldsrc = src
			src = null //dont kill proc after qdel()
			usr.drop_inv_item_on_ground(oldsrc)
			qdel(oldsrc)
			if(istype(O,/obj/item) && istype(usr,/mob/living/carbon))
				usr.put_in_hands(O)
		O.add_fingerprint(usr)
		//BubbleWrap - so newly formed boxes are empty
		if(istype(O, /obj/item/storage))
			for (var/obj/item/I in O)
				qdel(I)
		//BubbleWrap END
	if(src && usr.interactee == src) //do not reopen closed window
		spawn()
			interact(usr)
			return
	return

/obj/item/stack/proc/use(used)
	if(used > amount) //If it's larger than what we have, no go.
		return 0
	amount -= used
	if(amount <= 0)
		if(usr && loc == usr)
			usr.temp_drop_inv_item(src)
		qdel(src)
	return 1

/obj/item/stack/proc/add(var/extra)
	if(amount + extra > max_amount)
		return 0
	else
		amount += extra
	return 1

/obj/item/stack/proc/get_amount()
	return amount

/obj/item/stack/proc/add_to_stacks(mob/user)
	var/obj/item/stack/oldsrc = src
	src = null
	for (var/obj/item/stack/item in user.loc)
		if (item==oldsrc)
			continue
		if (!istype(item, oldsrc.type))
			continue
		if (item.amount>=item.max_amount)
			continue
		oldsrc.attackby(item, user)
		to_chat(user, "You add new [item.singular_name] to the stack. It now contains [item.amount] [item.singular_name]\s.")
		if(!oldsrc)
			break

/obj/item/stack/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		var/obj/item/stack/F = new src.type(user, 1)
		F.copy_evidences(src)
		user.put_in_hands(F)
		src.add_fingerprint(user)
		F.add_fingerprint(user)
		use(1)
		if (src && usr.interactee==src)
			spawn(0) src.interact(usr)
	else
		..()
	return

/obj/item/stack/attackby(obj/item/W as obj, mob/user as mob)
	..()
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		if(S.stack_id == stack_id) //same stack type
			if (S.amount >= max_amount)
				return 1
			var/to_transfer as num
			if (user.get_inactive_hand()==src)
				to_transfer = 1
			else
				to_transfer = min(src.amount, S.max_amount-S.amount)
			S.add(to_transfer)
			if (S && usr.interactee==S)
				spawn(0) S.interact(usr)
			src.use(to_transfer)
			if (src && usr.interactee==src)
				spawn(0) src.interact(usr)
			return TRUE

	return ..()

/obj/item/stack/proc/copy_evidences(obj/item/stack/from as obj)
	src.blood_DNA = from.blood_DNA
	src.fingerprints  = from.fingerprints
	src.fingerprintshidden  = from.fingerprintshidden
	src.fingerprintslast  = from.fingerprintslast
	//TODO bloody overlay

/*
 * Recipe datum
 */
/datum/stack_recipe
	var/title = "ERROR"
	var/result_type
	var/req_amount = 1
	var/res_amount = 1
	var/max_res_amount = 1
	var/time = 0
	var/one_per_turf = 0
	var/on_floor = 0
	var/skill_req = 0 //whether only people with sufficient construction skill can build this.

/datum/stack_recipe/New(title, result_type, req_amount = 1, res_amount = 1, max_res_amount = 1, time = 0, one_per_turf = 0, on_floor = 0, skill_req = 0)
	src.title = title
	src.result_type = result_type
	src.req_amount = req_amount
	src.res_amount = res_amount
	src.max_res_amount = max_res_amount
	src.time = time
	src.one_per_turf = one_per_turf
	src.on_floor = on_floor
	src.skill_req = skill_req

/*
 * Recipe list datum
 */
/datum/stack_recipe_list
	var/title = "ERROR"
	var/list/recipes = null
	var/req_amount = 1
	New(title, recipes, req_amount = 1)
		src.title = title
		src.recipes = recipes
		src.req_amount = req_amount