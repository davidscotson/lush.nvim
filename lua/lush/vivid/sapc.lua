-- This is the github JS tweaked to try to match the research code, so many of the
-- following comments will be talking about the github APCA W3C version.
--------------------------------------------------------------------------------
--[[ @preserve
----/                *** APCA VERSION for W3 and WCAG 3 ***
----/
----/   SAPC - S-Luv Advanced Perceptual Contrast - Beta Algorithm 0.98e_d12e
----/                *** With the NEW SmoothScale extension ***
----/              *** Optimized for the Font Select Extension ***
----/
----/   Functions to parse color values and determine SAPC/APCA contrast
----/   Copyright © 2019-2021 by Andrew Somers. All Rights Reserved.
----/   LICENSE: GNU AGPL v3  https:--www.gnu.org/licenses/
----/   CONTACT: For SAPC/APCA Please use the ISSUES tab at:
----/   https:--github.com/Myndex/SAPC-APCA/
-- ]]
--------------------------------------------------------------------------------
----/
----/                        SAPC Method and APCA Algorithm
----/          •••• Version 0.98e_d12e with SmoothScale™ by Andrew Somers ••••
----/
----/   GITHUB: https:--github.com/Myndex/SAPC-APCA
----/   DEVELOPER SITE: https:--www.myndex.com/WEB/Perception
----/
----/   Thanks To: 
----/   • This project references the research and work of Dr.Legge, Dr.Arditi,
----/     Dr.Lovie-Kitchin, M.Fairchild, R.Hunt, M.Stone, Dr.Poynton, L.Arend, &
----/     many others — see refs at https:--www.myndex.com/WEB/WCAG_CE17polarity
----/   • Stoyan Stefanov for his input parsing idea, Twitter @stoyanstefanov
----/   • Bruce Bailey of USAccessBoard for his encouragement, ideas, & feedback
----/   • Chris Loiselle of Oracle for getting us back on track in a pandemic
----/
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
----/
----/   *****  SAPC BLOCK  *****
----/
----/   For Evaluations, this is referred to as: SAPC-8, D-series constants
----/                S-LUV Advanced Perceptual Contrast
----/   Copyright © 2019-2021 by Andrew Somers. All Rights Reserved.
----/
----/
----/   INCLUDED Extensions or Model Features:
----/       • SAPC-8 Core Contrast
----/       • SmoothScale™ scaling technique
----/       • SoftToe black level soft clamp
----/
----/   NOT INCLUDED — This Version Does NOT Have These Extensions:
----/       • Color Vision Module
----/       • Spatial Frequency Module
----/       • Light Adaptation Module
----/       • Dynamics Module
----/       • Alpha Module
----/       • Personalization Module
----/       • Multiway Module
----/       • DynaFont™ font display
----/       • ResearchMode middle contrast explorer
----/       • ResearchMode static target
----/       • CIE function suite
----/       • SAPColor listings and sorting suite
----/       • RGBcolor() colorString parsing
----/
----/
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
------------------------------------------------------------------------------/
----/  BEGIN SAPC/APCA CONTRAST BLOCK  \--------------------------------------
----                                    \------------------------------------


----------------------------------------------------------------------------
----/ SAPC Function with SmoothScale  \------------------------------------
----                                   \----------------------------------
--/

----/ *** Polarity is Important: do not mix up background and text *** ----/

----/  Input value must be integer in RGB order (RRGGBB for 0xFFFFFF)  ----/

            ----/  DO NOT use a Y from any other method  ----/
local apc = {}

        ----/  MAGICAL NUMBERS  ------------------------------/

        ----/  sRGB Conversion to Relative Luminance (Y)  ----/

local  mainTRC = 2.4 -- Transfer Curve (aka "Gamma") for sRGB linearization
                      -- Simple power curve vs piecewise describen docs
                     -- Essentially, 2.4 best models actual displa
                    -- characteristics in combination with the total method

local  mainTRCencode = 0.41666666666666666667 -- = 1.0/mainTRC

local  Rco = 0.2126729        -- sRGB Red Coefficient (from matrix)
local  Gco = 0.7151522       -- sRGB Green Coefficient (from matrix)
local  Bco = 0.0721750        -- sRGB Blue Coefficient (from matrix)


        ----/  For Finding Raw SAPC Contrast from Relative Luminance (Y)  ----/

  
local  normBG = 0.56
local  normTXT = 0.57
local  revTXT = 0.62
local  revBG = 0.65


        ----/  For Clamping and Scaling Values  ----/

local blkThrs = 0.022
local blkClmp = 1.414 -- old 1.45 .. old inv  1.54967,
local blkClmpOut = 0.004530913 -- is math.pow(0.022,1.414) rnded+
local blkClmpInvert = 1.514845946588640 -- for inversion of 1.414 
local blkClmpInvFactor = 2.067216148486810  --// for inversion only

local scaleBoW = 1.14 --1.414
local scaleWoB = 1.14 --1.414

local loBoWthresh = 0.035991
local loBoWfactor = 27.7847239587675  --1/0.035991,
local loBoWoffset = 0.027

local loWoBthresh = 0.035991
local loWoBfactor = 27.7847239587675
local loWoBoffset = 0.027

local loClip = 0.001
local deltaYmin = 0.0005


function apc.contrast(Rbg, Gbg, Bbg, Rtxt, Gtxt, Btxt, places)
    places = places or 0;

    local Ybg =   math.pow(Rbg/255.0, mainTRC) * Rco +
                math.pow(Gbg/255.0, mainTRC) * Gco +
                math.pow(Bbg/255.0, mainTRC) * Bco

    local Ytxt =  math.pow(Rtxt/255.0, mainTRC) * Rco +
                math.pow(Gtxt/255.0, mainTRC) * Gco +
                math.pow(Btxt/255.0, mainTRC) * Bco

    -- Take Y and soft clamp black, ret 0 for very close luminances
    -- determine polarity, and calculate SAPC raw contrast
    -- Then apply the output scaling 

    -- Note that reverse contrast (white text on black)
    -- intentionally returns a negative number
    -- Proper polarity is important! 


----------   BLACK SOFT CLAMP & INPUT CLIP  --------------------------------

        -- Soft clamp Y when near black.
        -- Now clamping all colors to prevent crossover errors
    Ytxt = (Ytxt > blkThrs) and Ytxt or (Ytxt + math.pow(blkThrs - Ytxt, blkClmp))

    Ybg = (Ybg > blkThrs) and Ybg or (Ybg + math.pow(blkThrs - Ybg, blkClmp))

local outputContrast = 0.0   -- For weighted final values
local SAPC = 0.0             -- For holding raw SAPC values

        ----/   Return 0 Early for extremely low ∆Y (lint trap #1) ----/
    if (math.abs(Ybg - Ytxt) < deltaYmin) then
        outputcontrast = 0
    elseif ( Ybg > Ytxt ) then     -- For normal polarity, black text on white

            ----/ Calculate the SAPC contrast value and scale
        SAPC = ( math.pow(Ybg, normBG) - math.pow(Ytxt, normTXT) ) * scaleBoW

                ----/ NEW! SAPC SmoothScale™
               -- Low Contrast Smooth Scale Rollout to prevent polarity reversal
              -- and also a low clip for very low contrasts (lint trap #2)
             -- much of this is for very low contrasts, less than 10
            -- therefore for most reversing needs, only loConOffset is important
        if (SAPC < loClip) then
            outputContrast = 0.0
        elseif ( SAPC < loBoWthresh ) then
            outputContrast = SAPC - SAPC * loBoWfactor * loBoWoffset
        else
            outputContrast = SAPC - loBoWoffset
        end

    else      -- For reverse polarity, light text on dark
                -- WoB should always return negative value.

        SAPC = ( math.pow(Ybg, revBG) - math.pow(Ytxt, revTXT) ) * scaleWoB

        if (SAPC > -loClip) then
            outputContrast = 0.0
        elseif ( SAPC > -loWoBthresh ) then
            outputContrast = SAPC - SAPC * loWoBfactor * loWoBoffset
        else
            outputContrast = SAPC + loWoBoffset
        end
    end

    return  outputContrast * 100
end


function apc.YunClmp (YtoUnClamp)
    YtoUnclamp = YtoUnclamp or 1.0

    if (YtoUnClamp > blkThrs) then
        YtoUnClamp = YtoUnClamp
    elseif (YtoUnClamp < blkClmpOut) then
        YtoUnclamp = 0
    else
        YtoUnclamp = YtoUnclamp - blkClmpInvFactor * math.pow(blkThrs - YtoUnClamp, blkClmpInvert);
    end
    return YtoUnClamp
end

function apc.grayFromY(Y)
        local decimal = math.pow(Y,mainTRCencode)
        decimal = decimal * 255
        decimal = math.floor(.5 + decimal) -- do we need to round?
        return  math.min(255, decimal)
end

function apc.YFromRGB(red, green, blue, bg)
    bg = bg or false

    if (bg) then -- this is a background color
        Y =   math.pow(red/255.0, mainTRC) * Rco +
                math.pow(green/255.0, mainTRC) * Gco +
                math.pow(blue/255.0, mainTRC) * Bco

    else -- foreground text color
        Y =  math.pow(red/255.0, mainTRC) * Rco +
                math.pow(green/255.0, mainTRC) * Gco +
                math.pow(blue/255.0, mainTRC) * Bco
    end
    return Y
end

-- tweaked to accept and return Y, so color needs converted externally
-- not sure difference between negative contrast and swapping fg and bg
-- original commment *** not accurate for contrasts less than 8 ***
-- 
function apc.SAPCinverse (YtoClamp, returnbackground, targetContrast)
        returnbackground = returnbackground and true or false
        targetContrast = targetContrast or 90

        if (YtoClamp > blkThrs) then
            Y = YtoClamp
        else
            Y = YtoClamp + math.pow(blkThrs - YtoClamp, blkClmp);
        end

        if (targetContrast > 0) then
                BGexponent = normBG
                TXTexponent = normTXT
                scaleSAPC = scaleBoW
                SAPCoffset = loBoWoffset
        else
                BGexponent = revBG
                TXTexponent = revTXT
                scaleSAPC = scaleWoB
                SAPCoffset = -loWoBoffset
        end

        local SAPC = (targetContrast * 0.01 + SAPCoffset) / scaleSAPC

        if (not returnbackground) then
            Ynew = apc.YunClmp(
                        math.pow(
                        math.max(0, -1 * ( SAPC - math.pow(Y, BGexponent) )), 
                                                        1 / TXTexponent) )
        else
            Ynew = apc.YunClmp(
                        math.pow(
                        math.max(0, SAPC + math.pow(Y, TXTexponent)), 
                                            1 / BGexponent) )
        end
        return Ynew
    end

--
-- Test values to check
--  text, background, expected value from https://www.myndex.com/SAPC/
--
-- local function assertsame( a, b )
--     print (math.abs( a - b ) < 0.000000000001)
--   end
-- assertsame(apc.contrast(234, 116, 57, 255, 255, 255), -61.114778875982)
-- assertsame(apc.contrast(0, 0, 0, 170, 170, 170), -56.241133368397)
-- assertsame(apc.contrast(17, 34, 51, 221, 238, 255), -93.067700494843)
-- assertsame(apc.contrast(255, 255, 255, 136, 136, 136), 63.056469930209)

return apc
----\                            ------------------------------------------/\
----/\  END OF SAPC/APCA BLOCK  --------------------------------------------/\
------------------------------------------------------------------------------\
------------------------------------------------------------------------------/\

