/***********************************************************************
 * Copyright (c) 2009 Milan Jaitner                                   *
 * Distributed under the MIT software license, see the accompanying    *
 * file COPYING or https://www.opensource.org/licenses/mit-license.php.*
 ***********************************************************************/

#include "xmdmodel.h"
#include <stdio.h>
#include <string.h>

//#define _info

bool xmdModel::xmLoadBinaryXMDModel(const char *xmdModelPath) {
    FILE *pFile = fopen(xmdModelPath, "rb");
    if (!pFile) {
        printf("error: could not open file %s!\n", xmdModelPath);
        return false;
    }

    fread(headerTitle, 1, 74, pFile);
    fread(header, 1, 7, pFile);

    if (strcmp(header, "LXMD19")) {
        printf("error: file %s is not valid xmdModel file!\n");
        return false;
    }

    fread(&weaponBulletPosition, 1, sizeof(vec3), pFile);
    fread(&weaponSpritePosition, 1, sizeof(vec3), pFile);

    fread(&iNumObjects, 1, sizeof(short int), pFile);
#ifdef _info
    printf("%s\n", headerTitle);
    printf("iNumObjects: %d\n", iNumObjects);
#endif

    if (iNumObjects <= 0) return false;
    object = new xmlObject[iNumObjects];
    if (!object) return false;

    for (int o = 0; o < iNumObjects; o++) {
        short int lnght = 0;
        fread(&lnght, 1, sizeof(short int), pFile);
        fread(object[o].name, 1, lnght + 1, pFile);
#ifdef _info
        printf("%s %d %d\n",object[o].name, strlen(object[o].name), o);
#endif
        fread(&object[o].iNumVertices, 1, sizeof(long int), pFile);
        fread(&object[o].iNumFaces, 1, sizeof(long int), pFile);

#ifdef _info
        printf("%d %d\n",object[o].iNumVertices, object[o].iNumFaces);
#endif

        object[o].vertex = new vec3[object[o].iNumVertices];
        object[o].texcoord = new vec2[object[o].iNumVertices];
        object[o].normal = new vec3[object[o].iNumVertices];
        object[o].tangent = new vec3[object[o].iNumVertices];
        object[o].bitangent = new vec3[object[o].iNumVertices];
        object[o].face = new xmFace[object[o].iNumFaces];

        if (!object[o].vertex || !object[o].texcoord || !object[o].face || !object[o].normal || !object[o].tangent ||
            !object[o].bitangent) {
            printf("error: cannot alloc. memory for vertex, texcoords!\n");
            return false;
        }

        for (int v = 0; v < object[o].iNumVertices; v++) {
            fread(&object[o].vertex[v], 1, sizeof(vec3), pFile);
            fread(&object[o].texcoord[v], 1, sizeof(vec2), pFile);
#ifdef _info
            printf("%f %f %f  %f %f\n", object[o].vertex[v].x, object[o].vertex[v].y, object[o].vertex[v].z, object[o].texcoord[v].x, object[o].texcoord[v].y);
#endif
        }
        fread(object[o].face, object[o].iNumFaces, sizeof(xmFace), pFile);
#ifdef _info
        for(int f=0; f < object[o].iNumFaces; f++) printf("%d %d %d\n",object[o].face[f].a, object[o].face[f].b, object[o].face[f].c);
#endif
        fread(&lnght, 1, sizeof(short int), pFile);
        fread(object[o].texturePath, 1, lnght + 1, pFile);
        fread(&object[o].textureFilter, 1, sizeof(short int), pFile);
        fread(&object[o].opacity, 1, sizeof(float), pFile);
#ifdef _info
        printf("%s %d %f\n",object[o].texturePath, object[o].textureFilter, object[o].opacity);
#endif

        char tempTexName[1024];
        sprintf((char *) &tempTexName, "gamecore/weapons/%s", (char *) &(object[o].texturePath));

        char *normalMap = strtok(object[o].texturePath, ".");
        if (normalMap) {
            sprintf((char *) &tempTexName, "gamecore/weapons/%s_Normal.dds", normalMap);
        }

        min = max = vec3(0, 0, 0);

        for (int i = 0; i < object[o].iNumFaces; i++) {
            xmCalculateNTB(object[o].vertex[object[o].face[i].a], object[o].vertex[object[o].face[i].b],
                           object[o].vertex[object[o].face[i].c], object[o].texcoord[object[o].face[i].a],
                           object[o].texcoord[object[o].face[i].b], object[o].texcoord[object[o].face[i].c],
                           object[o].normal, object[o].bitangent, object[o].tangent, object[o].face[i]);

            if (min.x == 0) min.x = 999999.9f;
            if (max.x == 0) max.x = -999999.9f;
            if (min.z == 0) min.z = 999999.9f;
            if (max.z == 0) max.z = -999999.9f;
            if (min.y == 0) min.y = 999999.9f;
            if (max.y == 0) max.y = -999999.9f;

            int ind[3];
            ind[0] = object[o].face[i].a;
            ind[1] = object[o].face[i].b;
            ind[2] = object[o].face[i].c;

            for (int v = 0; v < 3; v++) {
                if (object[o].vertex[ind[v]].x < min.x) min.x = object[o].vertex[ind[v]].x - 2.0f;
                if (object[o].vertex[ind[v]].y < min.y) min.y = object[o].vertex[ind[v]].y - 2.0f;
                if (object[o].vertex[ind[v]].z < min.z) min.z = object[o].vertex[ind[v]].z - 2.0f;

                if (object[o].vertex[ind[v]].x > max.x) max.x = object[o].vertex[ind[v]].x + 2.0f;
                if (object[o].vertex[ind[v]].y > max.y) max.y = object[o].vertex[ind[v]].y + 2.0f;
                if (object[o].vertex[ind[v]].z > max.z) max.z = object[o].vertex[ind[v]].z + 2.0f;
            }
        }
    }

    center = ((max + min) / 2);
    radius = Distance(max, center);
    fclose(pFile);

    return true;
}


GLfloat light_pos[] = {25.0f, 25.0f, 25.0f, 1.0f};
GLfloat light_Ka[] = {1.0f, 1.0f, 1.0f, 1.0f};
GLfloat light_Kd[] = {1.0f, 1.0f, 1.0f, 1.0f};
GLfloat light_Ks[] = {1.0f, 1.0f, 1.0f, 1.0f};

void xmdModel::xmDrawXMDModel() {

    glDisable(GL_LIGHTING);

    glPushMatrix();
    {
        glColor3f(1, 0, 0);
        glPointSize(10);
        glBegin(GL_POINTS);
        {
            glVertex3f(weaponBulletPosition.x, weaponBulletPosition.y, weaponBulletPosition.z);
        }
        glEnd();
        glBegin(GL_POINTS);
        {
            glVertex3f(weaponSpritePosition.x, weaponSpritePosition.y, weaponSpritePosition.z);
        }
        glEnd();
        glColor3f(1, 1, 1);
    }
    glPopMatrix();

    glLightfv(GL_LIGHT0, GL_POSITION, light_pos);
    glLightfv(GL_LIGHT0, GL_AMBIENT, light_Ka);
    glLightfv(GL_LIGHT0, GL_DIFFUSE, light_Kd);
    glLightfv(GL_LIGHT0, GL_SPECULAR, light_Ks);
    glEnable(GL_LIGHT0);
    glEnable(GL_LIGHTING);

    for (int o = 0; o < iNumObjects; o++) {
        glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer(3, GL_FLOAT, 0, &object[o].vertex[0]);

        glEnableClientState(GL_NORMAL_ARRAY);
        glNormalPointer(GL_FLOAT, sizeof(vec3), &object[o].normal[0]);

        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
        glTexCoordPointer(2, GL_FLOAT, sizeof(vec2), &object[o].texcoord[0]);

        glDrawElements(GL_TRIANGLES, object[o].iNumFaces * 3, GL_UNSIGNED_INT, &object[o].face[0]);

        glDisable(GL_TEXTURE_COORD_ARRAY);
        glDisable(GL_NORMAL_ARRAY);
        glDisable(GL_VERTEX_ARRAY);

    }
}
