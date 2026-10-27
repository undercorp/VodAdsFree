package app.vodadsfree.patches.disneyplus.ads

import app.revanced.patcher.definingClass
import app.revanced.patcher.gettingFirstMethodDeclaratively
import app.revanced.patcher.name
import app.revanced.patcher.patch.BytecodePatchContext
import app.revanced.patcher.returnType

// The Disney Streaming (DSS / BAMTech) SDK keeps its class names, so these are stable across
// app releases. See services/disneyplus/analysis/ad-pipeline.md.

private const val INSERTION = "Lcom/dss/sdk/internal/media/Insertion;"

/** Points in the timeline where the server says an ad pod should be inserted. */
internal val BytecodePatchContext.insertionGetPointsMethod by gettingFirstMethodDeclaratively {
    name("getPoints")
    definingClass(INSERTION)
    returnType("Ljava/util/List")
}

/** Ranges of the timeline that are (or will become) ad content. */
internal val BytecodePatchContext.insertionGetRangesMethod by gettingFirstMethodDeclaratively {
    name("getRanges")
    definingClass(INSERTION)
    returnType("Ljava/util/List")
}
