// ============================================================================
// AIDE Lite - AI-powered IDE extension for Mendix Studio Pro
// Copyright (c) 2025-2026 Neel Desai / Golden Earth Software Consulting Inc.
// Extensions menu registration — AIDE Lite Chat menu item
// ============================================================================
using System.ComponentModel.Composition;
using Mendix.StudioPro.ExtensionsAPI.Services;
using Mendix.StudioPro.ExtensionsAPI.UI.Menu;
using Mendix.StudioPro.ExtensionsAPI.UI.Services;

namespace AideLite.Extensions;

// MEF discovers this class automatically via [Export].
// Adds the AIDE Lite Chat item under Studio Pro's Extensions menu.
[Export(typeof(MenuExtension))]
public class AideLiteMenuExtension : MenuExtension
{
    private readonly IDockingWindowService _dockingService;

    [ImportingConstructor]
    public AideLiteMenuExtension(
        IDockingWindowService dockingService,
        IDialogService dialogService,
        ILogService logService)
    {
        _dockingService = dockingService;
    }

    public override IEnumerable<MenuViewModel> GetMenus()
    {
        yield return new MenuViewModel(
            "AIDE Lite Chat",
            () => _dockingService.OpenPane(AideLitePaneExtension.PaneId)
        );
    }
}
