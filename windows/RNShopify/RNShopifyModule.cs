using ReactNative.Bridge;
using System;
using System.Collections.Generic;
using Windows.ApplicationModel.Core;
using Windows.UI.Core;

namespace Com.Reactlibrary.RNShopify
{
    /// <summary>
    /// A module that allows JS to share data.
    /// </summary>
    class RNShopifyModule : NativeModuleBase
    {
        /// <summary>
        /// Instantiates the <see cref="RNShopifyModule"/>.
        /// </summary>
        internal RNShopifyModule()
        {

        }

        /// <summary>
        /// The name of the native module.
        /// </summary>
        public override string Name
        {
            get
            {
                return "RNShopify";
            }
        }
    }
}
