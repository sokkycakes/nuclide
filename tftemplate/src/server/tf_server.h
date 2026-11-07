/*
 * Copyright (c) 2026 sokkycakes
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* prototypes for server/tf_api.qc, which the entity classes call into */
entity TF_NextObjective(entity previousObjective);
bool TF_CanCapture(entity pointEnt, float teamID);
entity TF_ObjectiveFor(float teamID);
float TF_KothTimeLeft(float teamID);
string TF_Mode(void);
entity TF_NextPickup(entity previousPickup);
string TF_PickupKind(entity pickupEnt);
float TF_PickupAmount(entity pickupEnt);
bool TF_PickupAvailable(entity pickupEnt);
void TF_Resupply(entity targetEnt);
void TF_RulesEvent(string eventName, entity activatorEnt, string eventData);
bool TF_RulesAllow(string checkName, entity targetEnt, float checkValue);
