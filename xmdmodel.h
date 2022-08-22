/***********************************************************************
 * Copyright (c) 2009 Milan Jaitner                                   *
 * Distributed under the MIT software license, see the accompanying    *
 * file COPYING or https://www.opensource.org/licenses/mit-license.php.*
 ***********************************************************************/

#ifndef _XMDMODEL_H
#define _XMDMODEL_H

#include "math/vector.h"
#include <gl/gl.h>

struct xmlObject {
    vec3 *vertex;
    vec3 *tangent;
    vec3 *bitangent;
    vec3 *normal;
    vec2 *texcoord;
    xmFace *face;
    vec3 min;
    vec3 max;
    vec3 center;
    float radius;
    long int iNumFaces;
    long int iNumVertices;
    char name[256];
    char texturePath[1024];
    short int textureFilter;
    float opacity;
    GLuint uDiffuseMap;
    GLuint uNormalMap;
};

class xmdModel {

public:
    bool xmLoadBinaryXMDModel(const char *xmdModelPath);

    void xmDrawXMDModel();

    short int iNumObjects;
    xmlObject *object;
    vec3 min;
    vec3 max;
    vec3 center;
    vec3 weaponBulletPosition;
    vec3 weaponSpritePosition;
    float radius;
    short int iNumMainShells;
    short int iNumShells;
    float fWeaponWeight;

private:
    char headerTitle[255];
    char header[7];

};

#endif
