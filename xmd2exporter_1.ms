
function myGetCorrespTVert iMeshVert iFace CurMesh =
(
	MeshFace = getFace CurMesh iFace
	TVFace = getTVFace CurMesh iFace
	if MeshFace.x == iMeshVert then
		return TVFace.x
	else if MeshFace.y == iMeshVert then 
		return TVFace.y
	else 
		return TVFace.z
)

function RotatePoint90X pntPoint iDir =
(
	pntRet = [pntPoint.x,0,0]
	if(iDir == 2) then
	(
		pntRet.y = pntPoint.z;
		pntRet.z = -pntPoint.y
	)
	else
	(
		pntRet.y = -pntPoint.z;
		pntRet.z = pntPoint.y
	)
	return pntRet
)


function MeshExport bRotateX90 iFileOut = 
(
	if(iFileOut == 1) then 
	(
		strFileName = getSaveFileName caption:"Save Orbiter Mesh File" types:"Orbiter Mesh File *.msh|*.msh"
		if strFileName == undefined then 
			return "Aborted"

		fsMeshFile = CreateFile strFileName
		if fsMeshFile == undefined then 
			return "Error ! Could not create file."
	)
	else
		fsMeshFile = StringStream "" 

	-- if we use a stringstream to dump the data to the output window
	-- we generate a little spacer to make it more clearly where the actual file begins
	if isKindOf fsMeshFile StringStream then
		format "\n\n" to:fsMeshFile

	-- first write the header
	format "# XMD FileFormat By Jatro 8D\n\n" to:fsMeshFile
  format "i version 10\n\n" to:fsMeshFile
  
	arrMeshes = #()
	arrTranspMeshes = #()
	arrNames = #()
	arrTranspNames = #()
	arrObjects = #()

	-- copy the scene object array, because in some cases (multiple groups) 
	-- it is temporarily mixed up later when the snapshots are taken
	for iObIndex = 1 to $objects.count do
		arrObjects[iObIndex] = $objects[iObIndex]
  format "w obj %\n" arrObjects.count to:fsMeshFile
	-- now copy all objects to an internal array and convert them to 
	-- Editable_Mesh for exporting
	for iObIndex = 1 to arrObjects.count do
	(
		AktObject = snapshot arrObjects[iObIndex]

		if AktObject == undefined or not isKindOf AktObject Editable_Mesh then 
		(
			print ("Skipping " + arrObjects[iObIndex].name + " ! Not convertable to Editable_Mesh.")
			if AktObject != undefined then 
				delete AktObject
		)
		else 
		(
			if isGroupMember AktObject then 
				setGroupMember AktObject false

			-- make sure, transparent objects are generated as the last objects in the mesh file
			if(AktObject.material != undefined and AktObject.material.opacity < 100.0) then
			(
				append arrTranspMeshes AktObject
				append arrTranspNames arrObjects[iObIndex].name
			)
			else
			(
				append arrMeshes AktObject
				append arrNames arrObjects[iObIndex].name
			)
		)
	)

	join arrMeshes arrTranspMeshes
	join arrNames arrTranspNames

	arrTextures = #()

	-- assemble an array with all the texturenames used in the scene now
	-- so we can calculate the correct texture index for each mesh
	for CurMat in sceneMaterials do 
	(
		if CurMat.diffusemap != undefined then
		(
			strTextureFileExploded = filterString CurMat.diffusemap.filename "\\."
			strTextureFile = strTextureFileExploded[strTextureFileExploded.count - 1]
			if findItem arrTextures strTextureFile == 0 then append arrTextures strTextureFile
		)
	)

	for iAktMesh = 1 to arrMeshes.count do
	(
		CurMesh = arrMeshes[iAktMesh]

		print ("Generating geometry data for " + arrNames[iAktMesh] + " as Group " + (iAktMesh-1) as string)

		-- output LABEL for current mesh
		--format "LABEL %\n" arrNames[iAktMesh] to:fsMeshFile

		-- output material index for current mesh
		if CurMesh.Material == undefined then iMat = 0
		else iMat = findItem sceneMaterials CurMesh.Material
		--format "MATERIAL %\n" iMat to:fsMeshFile

		-- output texture index 
		iTexIndex = 0
		if iMat > 0 and sceneMaterials[iMat].diffusemap != undefined then
		(
			strTextureFileExploded = filterString sceneMaterials[iMat].diffusemap.filename "\\."
			strTextureFile = strTextureFileExploded[strTextureFileExploded.count - 1]
			iTexIndex = findItem arrTextures strTextureFile 
		)
		--format "TEXTURE %\n" iTexIndex to:fsMeshFile 

		-- determine whether texture coordinates have to be created 
		bGenTexCoords = false
		if CurMesh.material != undefined and CurMesh.material.diffuseMap != undefined then 
			bGenTexCoords = true

		-- the following part is for handling vertices with multiple normals 
		-- since orbiter can only handle 1 normal per vertice those with multiple
		-- normals will now be split up so that each of the resulting vertices 
		-- has only one normal vector
		
		struct SFaceGroup (iSmoothGroup, arrFaces, iTVert)
		for iCurVert = 1 to CurMesh.verts.count do
		(
			-- now we determine for every vertex of the mesh, how many normals 
			-- it has.. this is done by examining the smoothing groups of the
			-- attached faces
			arrFaceGroups = #()
			arrVertFaces = meshop.getFacesUsingVert CurMesh iCurVert
			for iAktFace = 1 to arrVertFaces.count do
			(
				if arrVertFaces[iAktFace] then 
				(
					-- first we store one FaceGroup for every face of the vertex
					global FaceGroup = SFaceGroup iSmoothGroup:(getFaceSmoothGroup CurMesh iAktFace) arrFaces:#(iAktFace) iTVert:-1
					append arrFaceGroups FaceGroup
				)
			)
			if arrFaceGroups.count > 0 then
			(
				do
				(
					-- now we check which groups can be put together into one group
					-- according to their smoothgroup setting
					-- this is done until no two groups share any smoothing groups 
					bChanged = false
					for iAktFaceGroup = 1 to arrFaceGroups.count do
					(
						iCompFaceGroup = iAktFaceGroup+1
						while iCompFaceGroup <= arrFaceGroups.count do
						(
							if ((bit.and arrFaceGroups[iAktFaceGroup].iSmoothGroup arrFaceGroups[iCompFaceGroup].iSmoothGroup != 0)) then
							(
								iNewSmoothGroup = bit.or arrFaceGroups[iAktFaceGroup].iSmoothGroup arrFaceGroups[iCompFaceGroup].iSmoothGroup
								join arrFaceGroups[iAktFaceGroup].arrFaces arrFaceGroups[iCompFaceGroup].arrFaces
								arrFaceGroups[iAktFaceGroup].iSmoothGroup = iNewSmoothGroup
								deleteItem arrFaceGroups iCompFaceGroup
								bChanged = true
							)
							else
								iCompFaceGroup += 1
						)
					)
				)
				while bChanged

				-- the resulting number of groups is the number of normal vectors
				-- for our vertex thus the total number of vertices needed at this 
				-- position

				-- now if there are more than 1 group, a new vertex is created
				-- for each additional group and the faces of the group are
				-- reconnected to the new vertex
				for iAktGroup = 2 to arrFaceGroups.count do
				(
					iNewVertIndex = setNumVerts CurMesh (CurMesh.numverts+1) true
					setVert CurMesh iNewVertIndex CurMesh.verts[iCurVert].pos
					-- add texture vertex as well 
					for iAktFace in arrFaceGroups[iAktGroup].arrFaces do
					(
						AktFace = getFace CurMesh iAktFace
						if AktFace.x == iCurVert then 
							AktFace.x = iNewVertIndex
						else if AktFace.y == iCurVert then 
							AktFace.y = iNewVertIndex
						else 
							AktFace.z = iNewVertIndex
						setFace CurMesh iAktFace AktFace
					)								
				)
			)
			else
				print ("isolated vertex found: " + iCurVert as string)
		)
		update CurMesh

		-- now we need to store all the vertex normals, because they might be changed 
		-- when splitting vertices later
		arrNormals = #()
		for iAktVert = 1 to CurMesh.numverts do
			append arrNormals (getNormal CurMesh iAktVert)

		if bGenTexCoords then
		(
			-- next we examine the mesh again and split all vertices that have 
			-- more than one associated texture vertex

			-- create an array for the texture vertices, this will later store
			-- exactly one texturevertex for each mesh vertex
			arrTVerts = #()

			for iCurVert = 1 to CurMesh.verts.count do
			(
				arrFaceGroups = #()
				arrVertFaces = meshop.getFacesUsingVert CurMesh iCurVert
				for iAktFace = 1 to arrVertFaces.count do
				(
					if arrVertFaces[iAktFace] then 
					(
						-- first we store one FaceGroup for every face of the vertex
						global FaceGroup = SFaceGroup iSmoothGroup:-1 arrFaces:#(iAktFace) iTVert:(myGetCorrespTVert iCurVert iAktFace CurMesh)
						append arrFaceGroups FaceGroup
					)
				)
				if arrFaceGroups.count > 0 then
				(
					-- now we check which groups can be put together into one group
					-- because they have the same texturevertex associated
					for iAktFaceGroup = 1 to arrFaceGroups.count do
					(
						iCompFaceGroup = iAktFaceGroup+1
						while iCompFaceGroup <= arrFaceGroups.count do
						(
							if ((arrFaceGroups[iAktFaceGroup].iTVert == arrFaceGroups[iCompFaceGroup].iTVert) or 
								((getTVert CurMesh (arrFaceGroups[iAktFaceGroup].iTVert)) == (getTVert CurMesh (arrFaceGroups[iCompFaceGroup].iTVert)) ) ) then
							(
								join arrFaceGroups[iAktFaceGroup].arrFaces arrFaceGroups[iCompFaceGroup].arrFaces
								deleteItem arrFaceGroups iCompFaceGroup
							)
							else
								iCompFaceGroup += 1
						)
					)

					arrTVerts[iCurVert] = getTVert CurMesh (arrFaceGroups[1].iTVert)

					-- now if there are more than 1 group, a new vertex is created
					-- for each additional group and the faces of the group are
					-- reconnected to the new vertex
					for iAktGroup = 2 to arrFaceGroups.count do
					(
						iNewVertIndex = setNumVerts CurMesh (CurMesh.numverts+1) true
						setVert CurMesh iNewVertIndex CurMesh.verts[iCurVert].pos
						-- add texture vertex as well 
						arrTVerts[iNewVertIndex] = getTVert CurMesh arrFaceGroups[iAktGroup].iTVert
						arrNormals[iNewVertIndex] = arrNormals[iCurVert]
						for iAktFace in arrFaceGroups[iAktGroup].arrFaces do
						(
							AktFace = getFace CurMesh iAktFace
							if AktFace.x == iCurVert then 
								AktFace.x = iNewVertIndex
							else if AktFace.y == iCurVert then 
								AktFace.y = iNewVertIndex
							else 
								AktFace.z = iNewVertIndex
							setFace CurMesh iAktFace AktFace
						)								
					)
				)
			)
		)

		-- now that we got this done we can generate .msh data for the current mesh
			
		-- start of geometry data 
		format "\n#OBJECTS\n" to:fsMeshFile
    format "o %\n" arrNames[iAktMesh] to:fsMeshFile
    format "n % %\n" CurMesh.numverts CurMesh.numfaces to:fsMeshFile
    
	for iCurVert = 1 to CurMesh.numverts do
		(
			-- get vertex
			vertex = CurMesh.verts[iCurVert]
			if(bRotateX90) then
				vertex.pos = RotatePoint90X vertex.pos 2

			-- get normal vector
			pntVNormal = arrNormals[iCurVert]
			if(bRotateX90) then
				pntVNormal = RotatePoint90X pntVNormal 2
				
      -- bGenTexCoords = true
       
			if bGenTexCoords then
			(
		
				pntTVert = arrTVerts[iCurVert]

				format "v % % % % % \n" (vertex.pos.x*-1) (vertex.pos.y) (vertex.pos.z) pntTVert.x (pntTVert.y*-1.0+1.0) to:fsMeshFile
			)
		)



		-- now output the face definitions 
		for iCurFace = 1 to CurMesh.numfaces do
		(
			face = getFace CurMesh iCurFace
			format "f % % %\n" (face.x as integer - 1) (face.z as integer - 1) (face.y as integer - 1) to:fsMeshFile
		)
				format "\n#MATERIALS\n" to:fsMeshFile
				format "t %.bmp\n" strCurTex to:fsMeshFile
	)

	-- after all geometry data is generated, output the material definitions
	print "Generating Material definitions"
	--format "MATERIALS %\n" sceneMaterials.count to:fsMeshFile
	--for CurMat in sceneMaterials do
	--	format "%\n" CurMat.name to:fsMeshFile
	--for CurMat in sceneMaterials do
	--(
	--	format "MATERIAL %\n" CurMat.name to:fsMeshFile

		-- output the materials color definitions, opacity is stored in all color definitions
	--	format "% % % %\n" (CurMat.diffuse.r / 255.0) (CurMat.diffuse.g / 255.0) (CurMat.diffuse.b / 255.0) (CurMat.opacity / 100.0) to:fsMeshFile
	--	format "% % % %\n" (CurMat.ambient.r / 255.0) (CurMat.ambient.g / 255.0) (CurMat.ambient.b / 255.0) (CurMat.opacity / 100.0) to:fsMeshFile
	--	format "% % % % %\n" (CurMat.specular.r / 255.0) (CurMat.specular.g / 255.0) (CurMat.specular.b / 255.0) (CurMat.opacity / 100.0) (CurMat.specularlevel) to:fsMeshFile
	--	format "% % % %\n" (CurMat.selfIllumColor.r / 255.0) (CurMat.selfIllumColor.g / 255.0) (CurMat.selfIllumColor.b / 255.0) (CurMat.opacity / 100.0) to:fsMeshFile
	--)
	-- output texture names with a .dds extension, textures have to be converted to .dds format manually
	print "Generating Texture List"
	--format "TEXTURES %\n" arrTextures.count to:fsMeshFile
	--for strCurTex in arrTextures do
	--	format "%.dds\n" strCurTex to:fsMeshFile

	-- delete all the Editable_Mesh copies of the scene objects from the scene
	for CurMesh in arrMeshes do
		delete CurMesh

	-- if we use a stringstream to dump the data to the output window
	-- we generate a little stuff here for marking the end of the .msh file
	if isKindOf fsMeshFile StringStream then
		format "\n" to:fsMeshFile


	-- output the whole mesh file to the console window for copying
	-- comment this out if createFile works
	print "Done generating data."
	if(iFileOut == 2) then
	(
		if (getKBChar prompt:"Press <Space> to start dump now or <Esc> to abort...") == " " then
			print fsMeshFile 
		else print "Aborted"
	)
)

function MeshImport bRotateX90 =
(
	struct SMeshGroup (meshobj, iMat, iTex)
	strFileName = getOpenFileName caption:"Load Orbiter Mesh File" types:"Orbiter Mesh File *.msh|*.msh"

	if strFileName != undefined then 
	(
		fsMeshFile = openFile strFileName mode:"r";
		if fsMeshFile == undefined then return "Error ! Could not open file."
		if readLine fsMeshFile != "MSHX1" then return "Error ! Not a valid msh file." -- make sure this is a real orbiter mesh file
		strLine = readLine fsMeshFile			-- read line from file... 
		strChopLine = filterString strLine " "  -- and divide it in substrings
		iNumGroups = strChopLine[2] as integer  -- read Number of Groups

		meshGroups = #()
		for iAktGroup = 1 to iNumGroups do
		(
			newGroup = SMeshGroup()
			iNoNormal = 0
			meshName = undefined
			do
			(
				strLine = readLine fsMeshFile
				strChopLine = filterString strLine " \t"
				if strChopLine[1] == "MATERIAL" then			-- read Material Index
					newGroup.iMat = strChopLine[2] as integer + 1 
					-- + 1 because Arrays in gmax are 1 based, so Material 1 would be our "default material"

				if strChopLine[1] == "TEXTURE" then				-- read Texture Index
					newGroup.iTex = strChopLine[2] as integer
					-- this time not + 1 because TEXTURE 0 means no texture

				if strChopLine[1] == "NONORMAL" then		
					iNoNormal = 3

				if strChopLine[1] == "LABEL" then
					meshName = substring strLine 7 -1
			)
			while strChopLine[1] != "GEOM" 
			
			-- according to the .msh documentation the material and texture is 
			-- inherited from the previous group, if not specified, first group must specify them
			if(iAktGroup > 1) then
			(
				if newGroup.iMat == undefined then newGroup.iMat = meshGroups[iAktGroup-1].iMat  
				if newGroup.iTex == undefined then newGroup.iTex = meshGroups[iAktGroup-1].iTex
			)
			else
			(
				if newGroup.iMat == undefined then newGroup.iMat = 1
				if newGroup.iTex == undefined then newGroup.iTex = 0
			)

			-- get number of vertices and faces from the GEOM tag
			iVerts = strChopLine[2] as integer
			iFaces = strChopLine[3] as integer

			-- if we have Group names after the GEOM tag separated with a colon (i.e. atlantis.msh), we name our mesh-objects after them
			if (meshName == undefined) then
			(
				if (strChopLine[4] != undefined) then 
				(
					strChopLine = filterString strLine ";"
					meshName = substring strChopLine[2] 2 -1
				)
				else -- otherwise we name it "Group <nr>"
				(
					meshName = "Group " + iAktGroup as string
				)
			)
			print ("Reading Group " + iAktGroup as string + "/" + iNumGroups as string + " : " + meshName)
			arrTexCoords = #()
			arrVerts = #()
			arrNormals = #()
			arrFaces = #()

			for iAktVert = 1 to iVerts do
			(
				strLine = readLine fsMeshFile
				strChopLine = filterString strLine " \t"

				-- read vertices and normal vectors into the arrays and perform left hand to right hand conversion
				arrVerts[iAktVert] = [strChopLine[1] as float * -1, strChopLine[2] as float, strChopLine[3] as float]
				if (bRotateX90) then
					arrVerts[iAktVert] = RotatePoint90X arrVerts[iAktVert] 1

				if (iNoNormal == 0 and strChopLine[4] != undefined) then
				(
					arrNormals[iAktVert] = [strChopLine[4] as float * -1.0, strChopLine[5] as float, strChopLine[6] as float]
					if (bRotateX90) then
						arrNormals[iAktVert] = RotatePoint90X arrNormals[iAktVert] 1
				)

				-- if the group has a texture, read texture coordinates
				if newGroup.iTex != undefined and newGroup.iTex > 0 then 
				(
					if ((strChopLine[7-iNoNormal] != undefined) and (strChopLine[8-iNoNormal] != undefined)) then 
					(
						arrTexCoords[iAktVert] = [strChopLine[7-iNoNormal] as float, strChopLine[8-iNoNormal] as float * -1.0 + 1.0, 0]
					) 
					else 
					(
						arrTexCoords[iAktVert] = [0, 1.0, 0]
					)                    
				)      			
			)
			for iAktFace = 1 to iFaces do 
			(
				strLine = readLine fsMeshFile
				strChopLine = filterString strLine " \t"

				-- read in faces
				arrFaces[iAktFace] = [strChopLine[1] as integer + 1, strChopLine[3] as integer + 1, strChopLine[2] as integer + 1]
			)
			-- create the mesh
			newMesh = mesh vertices:arrVerts faces:arrFaces tverts:arrTexCoords
			
			-- set the normal vectors
			for iCurVert = 1 to iVerts do
			(
				if (arrNormals[iCurVert] != undefined) then
					setNormal newMesh iCurVert arrNormals[iCurVert]
			)

			-- create texture faces if we have a texture
			if newGroup.iTex != 0 then
			(
				buildTVFaces newMesh false
				for iAktFace = 1 to arrFaces.count do
					setTVFace newMesh iAktFace arrFaces[iAktFace]
			)
			newMesh.name = meshName

			-- to make sure gmax doesn't calculate its own smoothing groups, we 
			-- set all the faces to smoothing group 1 
			for iAktFace = 1 to newMesh.numfaces do
				setFaceSmoothGroup newMesh iAktFace 1

			-- at this point we look through the meshs vertices and weld all identical 
			-- vertices (same position and normal) to one
			for iCurVert = 1 to newMesh.numverts do
			(
				iCompVert = iCurVert+1
				while (iCompVert <= newMesh.numverts) do
				(
					-- compare the vertices and normals, for the normals we have to use
					-- the array we read from the file because gmax will recalculate 
					-- all the vertex normals when the first weld is done
					if (((getVert newMesh iCurVert) == (getVert newMesh iCompVert)) and 
						(arrNormals[iCurVert] == arrNormals[iCompVert])) then
					(
						meshop.weldVertSet newMesh #(iCurVert, iCompVert)
						deleteItem arrNormals iCompVert
					)						
					else
						iCompVert = iCompVert +1
				)
			)
					

			update newMesh

			newGroup.meshobj = newMesh

			-- store the mesh together with its material and texture indices in an array
			-- this is used later for mapping materials to the meshes
			meshGroups[iAktGroup] = newGroup
		)

		-- now create the material array
		-- index 1 is the standard material (white diffuse and opaque)
		newMat = standard()
		newMat.name = "default material"
		newMat.diffuse = color 255 255 255
		arrMaterials = #(newMat)

		strLine = readLine fsMeshFile
		strChopLine = filterString strLine " "
		if strChopLine[1] == "MATERIALS" then 
		(
			print "Reading Materials"
			-- get number of materials
			iNumMat = strChopLine[2] as integer
			-- read in the material names and create the materials 
			for iAktMat = 2 to iNumMat+1 do
			(
				arrMaterials[iAktMat] = standard()
				arrMaterials[iAktMat].name = readLine fsMeshFile
			)

			-- now read in the material specifications
			-- assuming that materials are in the same order as above
			for iAktMat = 2 to iNumMat+1 do
			(
				strLine = readLine fsMeshFile
				strChopLine = filterString strLine " "
				if strChopLine[1] == "MATERIAL" then
				(
													
					strLine = readLine fsMeshFile
					strChopLine = filterString strLine " "

					-- colors are converted to 255 range
					arrMaterials[iAktMat].diffuse = color (strChopLine[1] as float * 255 as integer) (strChopLine[2] as float * 255 as integer) (strChopLine[3] as float * 255 as integer)

					-- opacity is read from the diffuse color definition only and converted to percentage representation
					arrMaterials[iAktMat].opacity = strChopLine[4] as float * 100 as integer
					strLine = readLine fsMeshFile
					strChopLine = filterString strLine " "

					-- read ambient color
					arrMaterials[iAktMat].ambient = color (strChopLine[1] as float * 255 as integer) (strChopLine[2] as float * 255 as integer) (strChopLine[3] as float * 255 as integer)
					strLine = readLine fsMeshFile
					strChopLine = filterString strLine " "

					-- read specular color
					arrMaterials[iAktMat].specular = color (strChopLine[1] as float * 255 as integer) (strChopLine[2] as float * 255 as integer) (strChopLine[3] as float * 255 as integer)

					-- if specified read specular level
					if strChopLine[5] != undefined then 
						arrMaterials[iAktMat].specularlevel = strChopLine[5] as float
					strLine = readLine fsMeshFile
					strChopLine = filterString strLine " "

					-- read emissive color
					arrMaterials[iAktMat].useSelfIllumColor = on
					arrMaterials[iAktMat].selfIllumColor = color (strChopLine[1] as float * 255 as integer) (strChopLine[2] as float * 255 as integer) (strChopLine[3] as float * 255 as integer)
				)
			)
		)
		strLine = readLine fsMeshFile
		strChopLine = filterString strLine " "
		if strChopLine[1] == "TEXTURES" then 
		(
			print "Reading Textures"
			iNumTex = strChopLine[2] as integer
			strTexNames = #()

			-- read texture file names
			for iAktTex = 1 to iNumTex do
			(
				strLine = readLine fsMeshFile

				-- filenames are stored without extension (.dds) 
				strChopLine = filterString strLine "."
				strTexNames[iAktTex] = strChopLine[1]
			)
		)
		close fsMeshFile

		arrTexturedMaterials = #()
		arrMatTexKeys = #()
		for iAktGroup = 1 to iNumGroups do
		(
			aktGroup = meshGroups[iAktGroup]

			-- since gmax stores texture maps only as part of a material definition
			-- we have to create a gmax material for every material/texture combination
			-- that is actually used in the mesh file
			-- first we create a unique key for the combination
			iMatTexKey = (aktGroup.iMat) * 1000 + aktGroup.iTex

			-- then look it up in an array
			iArrIndex = findItem arrMatTexKeys iMatTexKey

			-- if the combination wasn't found, we create a new material with the texture
			if iArrIndex == 0 then 
			(
				append arrMatTexKeys iMatTexKey
				iArrIndex = arrMatTexKeys.count
				newTexturedMaterial = copy arrMaterials[aktGroup.iMat]
				if aktGroup.iTex > 0 then
				(
					-- if a texture is specified, we try loading a .bmp file
					-- with the texture name from the directory ..\textures relative to 
					-- the dir the mesh file is loaded from
					strMeshDir = getFilenamePath strFileName
					strTexDirChop = filterString strMeshDir "\\"
					strTexDir = ""
					for iDirIndex =1 to strTexDirChop.count-1 do
						strTexDir += strTexDirChop[iDirIndex] + "\\"
					strTexDir += "textures\\"

					-- unfortunately gmax doesn't support .dds files so the textures
					-- of a mesh have to be converted to .bmp format manually to be used in gmax
					newTexturedMaterial.diffuseMap = Bitmaptexture fileName:(strTexDir + strTexNames[aktGroup.iTex] + ".bmp")

					-- materials with a texture are marked with an additional comment in the material name 
					-- however if the string is already part of the material name (from a previous export)
					-- we don't append it a second time
					if (matchPattern newTexturedMaterial.name pattern:("*with Tex: " + strTexNames[aktGroup.iTex])) == false then
						newTexturedMaterial.name += (" with Tex: " + strTexNames[aktGroup.iTex])

					-- make sure the texturemap is visible in the viewport
					showTextureMap newTexturedMaterial true
				)

				-- store the new material in an array, the indices of which correspond
				-- to the arrMatTexKeys array
				arrTexturedMaterials[iArrIndex] = newTexturedMaterial
			)

			-- finally assign the material to the mesh
			meshGroups[iAktGroup].meshobj.material = arrTexturedMaterials[iArrIndex]		
		)
		print "Done"
	)
)

utility max2msh "Export *.msh file" 
( 
	checkbox cbXRot "Rotate mesh -90? around X" checked:true
	radiobuttons rbFileOut labels:#("Output to File", "Dump to Listener") 
		default:2
	button export "Start Export ..."

	on export pressed do 
		MeshExport cbXRot.checked rbFileOut.state

)

utility msh2max "Import *.msh file"
(
	checkbox cbXRot "Rotate mesh 90? around X" checked:true   
	button import "Start Import ..."

	on import pressed do 
		MeshImport cbXRot.checked 
	
)

