/* Pwm Init Function 
 * Here lies the pwm Init function regarding the Arm Cortex R5 uC
*/
void Pwm_InitChannel(uint32_t epwmBaseAddr,
                     uint32_t epwmCh,
                     uint32_t epwmFuncClk,
                     uint32_t epwmFreq,
                     uint32_t epwmDutyCycle,
                     uint32_t epwmPrescaler)
{
    EPWM_AqActionCfg  aqConfig;
    uint32_t pwmBaseFreq = 250000000 / epwmPrescaler;
    uint32_t pwmCompVal = (pwmBaseFreq/epwmFreq)*(100-epwmDutyCycle)/200;

    /* Configure Time base submodule */
    EPWM_tbTimebaseClkCfg(epwmBaseAddr, pwmBaseFreq, epwmFuncClk);
    EPWM_tbPwmFreqCfg(epwmBaseAddr, pwmBaseFreq, epwmFreq,
        EPWM_TB_COUNTER_DIR_UP_DOWN,
            EPWM_SHADOW_REG_CTRL_ENABLE);
    EPWM_tbSyncDisable(epwmBaseAddr);
    EPWM_tbSetSyncOutMode(epwmBaseAddr, EPWM_TB_SYNC_OUT_EVT_SYNCIN);
    EPWM_tbSetEmulationMode(epwmBaseAddr, EPWM_TB_EMU_MODE_FREE_RUN);

    /* Configure counter compare submodule */
    EPWM_counterComparatorCfg(epwmBaseAddr, EPWM_CC_CMP_A,
                              pwmCompVal, EPWM_SHADOW_REG_CTRL_ENABLE,
            EPWM_CC_CMP_LOAD_MODE_CNT_EQ_ZERO, TRUE);
    EPWM_counterComparatorCfg(epwmBaseAddr, EPWM_CC_CMP_B,
                              pwmCompVal, EPWM_SHADOW_REG_CTRL_ENABLE,
                              EPWM_CC_CMP_LOAD_MODE_CNT_EQ_ZERO, TRUE);

    /* Configure Action Qualifier Submodule */
    aqConfig.zeroAction = EPWM_AQ_ACTION_DONOTHING;
    aqConfig.prdAction = EPWM_AQ_ACTION_DONOTHING;
    aqConfig.cmpAUpAction = EPWM_AQ_ACTION_HIGH;
    aqConfig.cmpADownAction = EPWM_AQ_ACTION_LOW;
    aqConfig.cmpBUpAction = EPWM_AQ_ACTION_HIGH;
    aqConfig.cmpBDownAction = EPWM_AQ_ACTION_LOW;
    EPWM_aqActionOnOutputCfg(epwmBaseAddr, epwmCh, &aqConfig);

    /* Configure Dead Band Submodule */
    EPWM_deadbandBypass(epwmBaseAddr);

    /* Configure Chopper Submodule */
    EPWM_chopperEnable(epwmBaseAddr, FALSE);

    /* Configure trip zone Submodule */
    EPWM_tzTripEventDisable(epwmBaseAddr, EPWM_TZ_EVENT_ONE_SHOT, 0U);
    EPWM_tzTripEventDisable(epwmBaseAddr, EPWM_TZ_EVENT_CYCLE_BY_CYCLE, 0U);
}
